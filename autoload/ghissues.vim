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

  if "gissues/" in vim.current.buffer.name:
    s = vim.current.buffer.name.split("/")
    return s[1] + "/" + s[2]

  # get the directory the current file is in
  filepath = vim.eval("shellescape(expand('%:p:h'))")

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

def showIssueList(labels, ignore_cache = False):
  repourl = getRepoURI()

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
    upstream_issues = vim.eval("g:github_upstream_issues")
    if upstream_issues == 1:
      # try to get from what repo forked
      data = urllib2.urlopen(ghUrl("/")).read()
      repoinfo = json.loads(data)
      if repoinfo["fork"]:
        pullGithubIssueList(repoinfo["source"]["full_name"])

    pages_loaded = 0

    # non-string args correspond to vanilla issues request 
    # strings default to label unless they correspond to a state
    query_type = False
    if isinstance(query, basestring):
      query_type = "label"
    if query in ["open", "closed", "all"]:
      query_type = "state"

    # load the github API. github_repo looks like "jaxbot/github-issues.vim", for ex.
    if query_type == "state":
      url = ghUrl("/issues?state="+query)
    elif query_type == "label":
      url = ghUrl("/issues?labels="+query)
    else:
      url = ghUrl("/issues")
    try:
      github_datacache[repourl] = []
      while pages_loaded < int(vim.eval("g:github_issues_max_pages")):
        response = urllib2.urlopen(url)
        # JSON parse the API response, add page to previous pages if any
        github_datacache[repourl] += json.loads(response.read())
        pages_loaded += 1
        headers = response.info() # try to find the next page
        if 'Link' not in headers:
          break
        next_url_match = re.match(r"<(?P<next_url>[^>]+)>; rel=\"next\"", headers['Link'])
        if not next_url_match:
          break
        url = next_url_match.group('next_url')
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
  url = getRepoURI()

  if url == "":
    return

  issues = getIssueList(url, 0)
  for issue in issues:
    addToOmni(str(issue["number"]) + " " + issue["title"])
  for label in getLabels():
    addToOmni(str(label["name"]))
  for collaborator in getCollaborators():
    addToOmni(str(collaborator["login"]))

def addToOmni(toadd):
  vim.command("call add(b:omni_options, "+json.dumps(toadd)+")")

def showIssueBuffer(number):
  repourl = getRepoURI()
  if not vim.eval("g:github_same_window") == "1":
    vim.command("silent new")
  vim.command("edit gissues/" + repourl + "/" + number)

def showIssue():
  repourl = getRepoURI()

  parens = vim.current.buffer.name.split("/")
  number = parens[3]
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
  parens = vim.current.buffer.name.split("/")
  number = parens[3]

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
    request = urllib2.Request(url, json.dumps(issue))
    data = json.loads(urllib2.urlopen(request).read())
    parens[3] = str(data['number'])
    vim.current.buffer.name = parens[0] + "/" + parens[1] + "/" + parens[2] + "/" + parens[3]
  else:
    url = ghUrl("/issues/" + number)
    request = urllib2.Request(url, json.dumps(issue))
    request.get_method = lambda: 'PATCH'
    urllib2.urlopen(request)
  
  if commentmode == 3:
    url = ghUrl("/issues/" + parens[3] + "/comments")
    data = json.dumps({ 'body': comment })
    request = urllib2.Request(url, data)
    urllib2.urlopen(request)

  if commentmode == 3 or number == "new":
    showIssue()

  # mark it as "saved"
  vim.command("setlocal nomodified")

def setIssueData(issue):
  parens = vim.current.buffer.name.split("/")
  url = ghUrl("/issues/" + parens[3])
  request = urllib2.Request(url, json.dumps(issue))
  request.get_method = lambda: 'PATCH'
  urllib2.urlopen(request)

  showIssue()

def getLabels():
  global repo_labels

  rpUrl = getRepoURI()
  
  if repo_labels.get(rpUrl,''):
    return repo_labels[rpUrl]

  url = ghUrl("/labels")
  repo_labels[rpUrl] = json.loads(urllib2.urlopen(url).read())

  return repo_labels[rpUrl]

def getCollaborators():
  global repo_collaborators

  rpUrl = getRepoURI()
  
  if repo_collaborators.get(rpUrl,''):
    return repo_collaborators[rpUrl]

  url = ghUrl("/collaborators")
  repo_collaborators[rpUrl] = json.loads(urllib2.urlopen(url).read())

  return repo_collaborators[rpUrl]

def highlightColoredLabels(labels):
  labels.append({ 'name': 'closed', 'color': 'ff0000'})
  labels.append({ 'name': 'open', 'color': '00aa00'})

  for label in labels:
    vim.command("hi issueColor" + label["color"] + " guifg=#fff guibg=#" + label["color"])
    vim.command("let m = matchadd(\"issueColor" + label["color"] + "\", \"" + label["name"] + "\")")

def ghUrl(endpoint):
  params = ""
  token = vim.eval("g:github_access_token")
  if token:
    if "?" in endpoint:
      params = "&"
    else:
      params = "?"
    params += "access_token=" + token
  return vim.eval("g:github_api_url") + "repos/" + urllib2.quote(getRepoURI()) + endpoint + params
EOF

function! ghissues#init()
  let g:github_issues_pyloaded = 1
endfunction

