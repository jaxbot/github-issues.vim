" core is written in Python for easy JSON/HTTP support
" do not continue if Vim is not compiled with Python2.7 support
if !has("python") || exists("g:github_issues_pyloaded")
  finish
endif

python <<EOF
import os
import vim
import json
import urllib2
import re

# dictionary of github repo URLs for caching
github_repos = {}
# dictionary of issue data for caching
github_datacache = {}
# reset web cache after this value grows too large
cache_count = 0

repo_labels = {}
repo_collaborators = {}

def getRepoURI():
  global github_repos

  if "gissues" in vim.current.buffer.name:
    s = getFilenameParens()
    return s[0] + "/" + s[1]

  # get the directory the current file is in
  filepath = vim.eval("shellescape(expand('%:p:h'))")

  if ".git" in filepath:
    filepath = filepath.replace(".git", "")

  # cache the github repo for performance
  if github_repos.get(filepath,'') != '':
    return github_repos[filepath]

  cmd = '(cd ' + filepath + ' && git remote -v)'

  filedata = os.popen(cmd).read()

  # possible URLs
  urls = vim.eval("g:github_issues_urls")
  for url in urls:
    s = filedata.split(url)
    if len(s) > 1:
      s = s[1].split()[0].split(".git")
      github_repos[filepath] = s[0]
      return s[0]
  return ""

def getUpstreamRepoURI():
  repourl = getRepoURI()
  if repourl == "":
    return ""

  upstream_issues = int(vim.eval("g:github_upstream_issues"))
  if upstream_issues == 1:
    # try to get from what repo forked
    repoinfo = ghApi("", repourl)
    if repoinfo and repoinfo["fork"]:
      repourl = repoinfo["source"]["full_name"]

  return repourl

# displays the issues in a vim buffer
def showIssueList(labels, ignore_cache = False):
  repourl = getUpstreamRepoURI()

  if repourl == "":
    print "Failed to find a suitable Github repository URL, sorry!"
    return

  if not vim.eval("g:github_same_window") == "1":
    vim.command("silent new")
  vim.command("edit " + "gissues/" + repourl + "/issues")
  vim.command("normal ggdG")

  b = vim.current.buffer
  issues = getIssueList(repourl, labels, ignore_cache)

  # its an array, so dump these into the current (issues) buffer
  for issue in issues:
    issuestr = str(issue["number"]) + " " + issue["title"] + " "  

    for label in issue["labels"]:
      issuestr += label["name"] + " "

    b.append(issuestr.encode(vim.eval("&encoding")))

  highlightColoredLabels(getLabels())

  # append leaves an unwanted beginning line. delete it.
  vim.command("1delete _")
  
def getIssueList(repourl, query, ignore_cache = False):
  global cache_count, github_datacache
  
  if ignore_cache or github_datacache.get(repourl,'') == '' or len(github_datacache[repourl]) < 1 or cache_count > 3:
    # non-string args correspond to vanilla issues request 
    # strings default to label unless they correspond to a state
    query_type = False
    if isinstance(query, basestring):
      query_type = "label"
    if query in ["open", "closed", "all"]:
      query_type = "state"

    # load the github API. github_repo looks like "jaxbot/github-issues.vim", for ex.
    try:
      github_datacache[repourl] = []
      more_to_load = True

      page = 1

      while more_to_load and page <= int(vim.eval("g:github_issues_max_pages")):
        if query_type == "state":
          url = ghUrl("/issues?state="+query+"&page=" + str(page), repourl)
        elif query_type == "label":
          url = ghUrl("/issues?labels="+query+"&page=" + str(page), repourl)
        else:
          url = ghUrl("/issues?page=" + str(page), repourl)

        response = urllib2.urlopen(url)
        issuearray = json.loads(response.read())

        # JSON parse the API response, add page to previous pages if any
        github_datacache[repourl] += issuearray

        more_to_load = len(issuearray) == 30

        page += 1

    except urllib2.URLError as e:
      github_datacache[repourl] = []
    except urllib2.HTTPError as e:
      if e.code == 410:
        github_datacache[repourl] = []
    cache_count = 0
  else:
    cache_count += 1

  return github_datacache[repourl]

def populateOmniComplete():
  url = getUpstreamRepoURI()

  if url == "":
    return

  issues = getIssueList(url, 0)
  for issue in issues:
    addToOmni(str(issue["number"]) + " " + issue["title"])
  labels = getLabels()
  if labels:
    for label in labels:
      addToOmni(str(label["name"]))
  collaborators = getCollaborators()
  if collaborators:
    for collaborator in collaborators:
      addToOmni(str(collaborator["login"]))

def addToOmni(keyword):
  vim.command("call add(b:omni_options, "+json.dumps(keyword)+")")

def showIssueBuffer(number):
  repourl = getRepoURI()
  if not vim.eval("g:github_same_window") == "1":
    vim.command("silent new")
  vim.command("edit gissues/" + repourl + "/" + number)

def showIssue():
  repourl = getRepoURI()

  parens = getFilenameParens()
  number = parens[2]
  b = vim.current.buffer
  vim.command("normal ggdG")

  if number == "new":
    # new issue
    issue = { 'title': '',
      'body': '',
      'number': 'new',
      'user': {
        'login': ''
      },
      'assignee': '',
      'state': 'open',
      'labels': []
    }
  else:
    url = ghUrl("/issues/" + number)
    issue = json.loads(urllib2.urlopen(url).read())

  b.append("# " + issue["title"].encode(vim.eval("&encoding")) + " (" + str(issue["number"]) + ")")
  if issue["user"]["login"]:
    b.append("## Reported By: " + issue["user"]["login"].encode(vim.eval("&encoding")))

  b.append("## State: " + issue["state"])
  if issue['assignee']:
    b.append("## Assignee: " + issue["assignee"]["login"].encode(vim.eval("&encoding")))
  elif number == "new":
    b.append("## Assignee: ")

  labelstr = ""
  if issue["labels"]:
    for label in issue["labels"]:
      labelstr += label["name"] + ", "
  b.append("## Labels: " + labelstr)

  if issue["body"]:
    b.append(issue["body"].encode(vim.eval("&encoding")).split("\n"))

  if number != "new":
    b.append("## Comments")

    url = ghUrl("/issues/" + number + "/comments")
    data = urllib2.urlopen(url).read()
    comments = json.loads(data)

    url = ghUrl("/issues/" + number + "/events")
    data = urllib2.urlopen(url).read()
    events = json.loads(data)

    events = comments + events

    if len(events) > 0:
      for event in events:
        b.append("")
        if "user" in event:
          user = event["user"]["login"]
        else:
          user = event["actor"]["login"]

        b.append(user.encode(vim.eval("&encoding")) + "(" + event["created_at"] + ")")

        if "body" in event:
          b.append(event["body"].encode(vim.eval("&encoding")).split("\n"))
        else:
          eventstr = event["event"].encode(vim.eval("&encoding"))
          if "commit_id" in event and event["commit_id"]:
            eventstr += " from " + event["commit_id"]
          b.append(eventstr)
  
    else:
      b.append("")
      b.append("No comments.")
      b.append("")
  
    b.append("## Add a comment")
    b.append("")
  
  vim.command("set ft=gfimarkdown")
  vim.command("normal ggdd")

  highlightColoredLabels(getLabels())

  # mark it as "saved"
  vim.command("setlocal nomodified")

def saveGissue():
  parens = getFilenameParens()
  number = parens[2]

  issue = {
    'title': '',
    'body': '',
  }

  issue['title'] = vim.current.buffer[0].split("# ")[1].split(" (" + number + ")")[0]

  commentmode = 0

  comment = ""
  
  for line in vim.current.buffer[1:]:
    if commentmode == 1:
      if line == "## Add a comment":
        commentmode = 2
      continue
    if commentmode == 2:
      if line != "":
        commentmode = 3
        comment += line + "\n"
      continue
    if commentmode == 3:
      comment += line + "\n"
      continue
      
    if line == "## Comments":
      commentmode = 1
      continue
    if len(line.split("## Reported By:")) > 1:
      continue

    state = line.split("## State: ")
    if len(state) > 1:
      if state[1].lower() == "closed":
        issue['state'] = "closed"
      else: issue['state'] = "open"
      continue

    labels = line.split("## Labels: ")
    if len(labels) > 1:
      issue['labels'] = labels[1].split(', ')
      continue

    assignee = line.split("## Assignee: ")
    if len(assignee) > 1 and assignee[1]:
      issue['assignee'] = assignee[1]
      continue

    if issue['body'] != '':
      issue['body'] += '\n'
    issue['body'] += line

  # remove blank entries
  issue['labels'] = filter(bool, issue['labels'])
  
  if number == "new":
    url = ghUrl("/issues")
    try:
      request = urllib2.Request(url, json.dumps(issue))
      data = json.loads(urllib2.urlopen(request).read())
    except urllib2.HTTPError as e:
      if e.code == 410:
        print "Error: Github returned code 410. Do you have a github_access_token defined?"
		
    parens[2] = str(data['number'])
    vim.current.buffer.name = "gissues/" + parens[0] + "/" + parens[1] + "/" + parens[2]
  else:
    url = ghUrl("/issues/" + number)
    request = urllib2.Request(url, json.dumps(issue))
    request.get_method = lambda: 'PATCH'
    urllib2.urlopen(request)
  
  if commentmode == 3:
    url = ghUrl("/issues/" + parens[2] + "/comments")
    data = json.dumps({ 'body': comment })
    request = urllib2.Request(url, data)
    urllib2.urlopen(request)

  if commentmode == 3 or number == "new":
    showIssue()

  # mark it as "saved"
  vim.command("setlocal nomodified")

def setIssueData(issue):
  parens = getFilenameParens()
  url = ghUrl("/issues/" + parens[2])
  request = urllib2.Request(url, json.dumps(issue))
  request.get_method = lambda: 'PATCH'
  urllib2.urlopen(request)

  showIssue()

def getLabels():
  global repo_labels

  rpUrl = getRepoURI()
  
  if repo_labels.get(rpUrl,''):
    return repo_labels[rpUrl]

  repo_labels[rpUrl] = ghApi("/labels")

  return repo_labels[rpUrl]

def getCollaborators():
  global repo_collaborators

  rpUrl = getRepoURI()
  
  if repo_collaborators.get(rpUrl,''):
    return repo_collaborators[rpUrl]

  repo_collaborators[rpUrl] = ghApi("/collaborators")

  return repo_collaborators[rpUrl]

def highlightColoredLabels(labels):
  if not labels:
    labels = []

  labels.append({ 'name': 'closed', 'color': 'ff0000'})
  labels.append({ 'name': 'open', 'color': '00aa00'})

  for label in labels:
    vim.command("hi issueColor" + label["color"] + " guifg=#ffffff guibg=#" + label["color"])
    vim.command("let m = matchadd(\"issueColor" + label["color"] + "\", \"" + label["name"] + "\")")

def ghApi(endpoint, repourl = False):
  try:
    req = urllib2.urlopen(ghUrl(endpoint, repourl), timeout = 5)
    return json.loads(req.read())
  except:
    return None

def ghUrl(endpoint, repourl = False):
  params = ""
  token = vim.eval("g:github_access_token")
  if token:
    if "?" in endpoint:
      params = "&"
    else:
      params = "?"
    params += "access_token=" + token
  if not repourl:
    repourl = getRepoURI()

  return vim.eval("g:github_api_url") + "repos/" + urllib2.quote(repourl) + endpoint + params

def getFilenameParens():
    return vim.current.buffer.name.replace("\\", "/").split("gissues/")[1].split("/")
EOF

function! ghissues#init()
  let g:github_issues_pyloaded = 1
endfunction

" vim: softtabstop=2 expandtab shiftwidth=2 tabstop=2
