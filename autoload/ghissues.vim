" core is written in Python for easy JSON/HTTP support
" do not continue if Vim is not compiled with Python2.7 support
if !has("python") || exists("g:github_issues_pyloaded")
  finish
endif

python <<EOF
import os
import sys
import vim
import string
import json
import urllib2
import subprocess
import threading

# dictionaries for caching
# repo urls on github by filepath
github_repos = {}
# issues by repourl
github_datacache = {}
# api data by repourl + / + endpoint
api_cache = {}

# reset web cache after this value grows too large
cache_count = 0

# whether or not SSL is known to be enabled
ssl_enabled = False

# returns the Github url (i.e. jaxbot/vimfiles) for the current file
def getRepoURI():
  global github_repos

  if "gissues" in vim.current.buffer.name:
    s = getFilenameParens()
    return s[0] + "/" + s[1]

  # get the directory the current file is in
  filepath = vim.eval("expand('%:p:h')")

  # Remove trailing ".git" segment from path.
  # While `git remote -v` appears to work from here in general, it fails when
  # invoked for COMMIT_EDITMSG: `fatal: Not a git repository: '.git'`.
  filepath = filepath.split(os.path.sep+".git")[0]

  # cache the github repo for performance
  if github_repos.get(filepath, None) is not None:
    return github_repos[filepath]

  # Get info for all remotes.
  # Do this first: if it fails, we're not in a Git repo.
  try:
    all_remotes = subprocess.check_output(
      ['git', 'remote', '-v'], cwd=filepath)
  except subprocess.CalledProcessError:
    github_repos[filepath] = ""
    return github_repos[filepath]

  # Try to get the remote for the current branch/HEAD.
  try:
    remote_ref = subprocess.check_output(
      'git rev-parse --abbrev-ref --verify --symbolic-full-name @{upstream}'.split(" "),
      stderr=subprocess.STDOUT
    )
  except subprocess.CalledProcessError:
    # Use the first one we find instead
    remote = None
    #print("github-issues: using default remote: %s" % remote)
  else:
    try:
      branch = subprocess.check_output(["git", "symbolic-ref", "--short", "HEAD"])
    except subprocess.CalledProcessError:
      # Branch could not be determined, do not filter by remote.
      remote = None
    else:
      # Remove "/branch" from the end of remote_ref to get the remote.
      remote = remote_ref[:-(len(branch)+1)]

  # possible URLs
  possible_urls = vim.eval("g:github_issues_urls")

  for line in all_remotes.split("\n"):
    try:
      cur_remote, url = line.split("\t")
    except ValueError:
      continue

    # Filter out non-matching remotes.
    if remote and remote != cur_remote:
      continue

    # Remove " (fetch)"/" (pull)" and ".git" suffixes.
    url = url.split(" ", 1)[0].split(".git", 1)[0]

    # Skip any unwanted urls.
    for possible_url in possible_urls:
      s = url.split(possible_url)
      if len(s) > 1:
        github_repos[filepath] = s[1]
        #print("github-issues: using repo: %s" % s[1])
        break
    else:
      continue
    break
  else:
    github_repos[filepath] = ""

  return github_repos[filepath]

# returns the repo uri, taking into account forks
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
    print("github-issues.vim: Failed to find a suitable Github repository URL, sorry!")
    vim.command("let github_failed = 1")
    return

  if not vim.eval("g:github_same_window") == "1":
    vim.command("silent new")

  # Some Vim versions don't allow noswapfile as a verb
  try:
    vim.command("noswapfile edit " + "gissues/" + repourl + "/issues")
  except:
    vim.command("edit " + "gissues/" + repourl + "/issues")

  vim.command("normal ggdG")

  b = vim.current.buffer
  issues = getIssueList(repourl, labels, ignore_cache)

  cur_milestone = str(vim.eval("g:github_current_milestone"))

  # its an array, so dump these into the current (issues) buffer
  for issue in issues:
    if cur_milestone != "" and (not issue["milestone"] or issue["milestone"]["title"] != cur_milestone):
      continue

    issuestr = str(issue["number"]) + " " + issue["title"] + " "

    for label in issue["labels"]:
      issuestr += label["name"] + " "

    b.append(issuestr.encode(vim.eval("&encoding")))

  if len(b) < 2:
    b.append("No results found in " + repourl)
    if cur_milestone:
      b.append("Filtering by milestone: " + cur_milestone)
    if labels:
      b.append("Filtering by labels: " + labels)

  highlightColoredLabels(getLabels())

  # append leaves an unwanted beginning line. delete it.
  vim.command("1delete _")

def showMilestoneList(labels, ignore_cache = False):
  repourl = getUpstreamRepoURI()

  vim.command("silent new")

  # Some Vim versions don't allow noswapfile as a verb
  try:
    vim.command("noswapfile edit " + "gissues/" + repourl + "/milestones")
  except:
    vim.command("edit " + "gissues/" + repourl + "/milestones")
  vim.command("normal ggdG")

  b = vim.current.buffer
  b.append("[None]")

  milestones = getMilestoneList(repourl, labels, ignore_cache)

  for mstone in milestones:
    mstonestr = mstone["title"]

    b.append(mstonestr.encode(vim.eval("&encoding")))

  vim.command("1delete _")

# pulls the issue array from the server
def getIssueList(repourl, query, ignore_cache = False):
  global github_datacache

  # non-string args correspond to vanilla issues request
  # strings default to label unless they correspond to a state
  params = {}
  if isinstance(query, basestring):
    params = { "label": query }
  if query in ["open", "closed", "all"]:
    params = { "state": query }

  return getGHList(ignore_cache, repourl, "/issues", params)

# pulls the milestone list from the server
def getMilestoneList(repourl, query = "", ignore_cache = False):
  global github_datacache

  # TODO Add support for 'state', 'sort', 'direction'
  params = {}

  return getGHList(ignore_cache, repourl, "/milestones", params)

def getGHList(ignore_cache, repourl, endpoint, params):
  global cache_count, github_datacache

  # Maybe initialise
  if github_datacache.get(repourl, '') == '' or len(github_datacache[repourl]) < 1:
    github_datacache[repourl] = {}

  ignore_cache = False
  if (ignore_cache or
      cache_count > 3 or
      github_datacache[repourl].get(endpoint,'') == '' or
      len(github_datacache[repourl].get(endpoint,'')) < 1):

    # load the github API. github_repo looks like "jaxbot/github-issues.vim", for ex.
    try:
      github_datacache[repourl][endpoint] = []
      more_to_load = True

      page = 1
      params['page'] = str(page)

      while more_to_load and page <= int(vim.eval("g:github_issues_max_pages")):

        # TODO This should be in ghUrl() I think
        qs = string.join([ k+'='+v for ( k, v ) in params.items()], '&')
        url = ghUrl(endpoint+'?'+qs, repourl)

        response = urllib2.urlopen(url)
        issuearray = json.loads(response.read())

        # JSON parse the API response, add page to previous pages if any
        github_datacache[repourl][endpoint] += issuearray

        more_to_load = len(issuearray) == 30

        page += 1

    except urllib2.URLError as e:
      github_datacache[repourl][endpoint] = []
      if "code" in e and e.code == 404:
        print("github-issues.vim: Error: Do you have a github_access_token defined?")

    cache_count = 0
  else:
    cache_count += 1

  return github_datacache[repourl][endpoint]

# populate the omnicomplete synchronously or asynchronously, depending on mode
def populateOmniComplete():
  if vim.eval("g:gissues_async_omni"):
    populateOmniCompleteAsync()
  else:
    doPopulateOmniComplete()

# adds issues, labels, and contributors to omni dictionary
def doPopulateOmniComplete():
  url = getUpstreamRepoURI()

  if url == "":
    return

  issues = getIssueList(url, 0)
  for issue in issues:
    addToOmni(str(issue["number"]) + " " + issue["title"], 'Issue')

  labels = getLabels()
  if labels is not None:
    for label in labels:
      addToOmni(str(label["name"]), 'Label')

  contributors = getContributors()
  if contributors is not None:
    for contributor in contributors:
      addToOmni(str(contributor["author"]["login"]), 'user')

  milestones = getMilestoneList(url)
  if milestones is not None:
    for milestone in milestones:
      addToOmni(str(milestone["title"].encode('utf-8')), 'Milestone')

# calls populateOmniComplete asynchronously
def populateOmniCompleteAsync():
  thread = AsyncOmni()
  thread.start()

class AsyncOmni(threading.Thread):
  def run(self):
    # Download and cache the omnicomplete data
    url = getUpstreamRepoURI()

    if url == "":
      return

    issues = getIssueList(url, 0)
    labels = getLabels()
    contributors = getContributors()
    milestones = getMilestoneList(url)

# adds <keyword> to omni dictionary. used by populateOmniComplete
def addToOmni(keyword, typ):
  vim.command("call add(b:omni_options, "+json.dumps({ 'word': keyword, 'menu': '[' + typ + ']' })+")")

# simply opens a buffer based on repourl and issue <number>
def showIssueBuffer(number, url = ""):
  if url != "":
    repourl = url
  else:
    repourl = getUpstreamRepoURI()

  if not vim.eval("g:github_same_window") == "1":
    vim.command("silent new")
  vim.command("edit gissues/" + repourl + "/" + number)

# show an issue buffer in detail
def showIssue():
  repourl = getUpstreamRepoURI()

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

  b.append("## Title: " + issue["title"].encode(vim.eval("&encoding")) + " (" + str(issue["number"]) + ")")
  if issue["user"]["login"]:
    b.append("## Reported By: " + issue["user"]["login"].encode(vim.eval("&encoding")))

  b.append("## State: " + issue["state"])
  if issue['assignee']:
    b.append("## Assignee: " + issue["assignee"]["login"].encode(vim.eval("&encoding")))
  elif number == "new":
    b.append("## Assignee: ")

  if number == "new":
    b.append("## Milestone: ")
  elif issue['milestone']:
    b.append("## Milestone: " + str(issue["milestone"]["title"]))

  labelstr = ""
  if issue["labels"]:
    for label in issue["labels"]:
      labelstr += label["name"] + ", "
  b.append("## Labels: " + labelstr[:-2])

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

# saves an issue and pushes it to the server
def saveGissue():
  parens = getFilenameParens()
  number = parens[2]

  issue = {
    'title': '',
    'body': '',
    'assignee': '',
    'labels': '',
    'milestone': ''
  }

  commentmode = 0

  comment = ""

  for line in vim.current.buffer:
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

    title = line.split("## Title:")
    if len(title) > 1:
      issue['title'] = title[1].strip().split(" (" + number + ")")[0]
      continue

    state = line.split("## State:")
    if len(state) > 1:
      if state[1].strip().lower() == "closed":
        issue['state'] = "closed"
      else: issue['state'] = "open"
      continue

    milestone = line.split("## Milestone:")
    if len(milestone) > 1:
      milestones = getMilestoneList(parens[0] + "/" + parens[1], "")

      milestone = milestone[1].strip()

      for mstone in milestones:
        if mstone["title"] == milestone:
          issue['milestone'] = str(mstone["number"])
          break
      continue

    labels = line.split("## Labels:")
    if len(labels) > 1:
      issue['labels'] = labels[1].lstrip().split(', ')
      continue

    assignee = line.split("## Assignee:")
    if len(assignee) > 1:
      issue['assignee'] = assignee[1].strip()
      continue

    if line[:1] == "#":
      # ignore any unknown comments
      continue

    if issue['body'] != '':
      issue['body'] += '\n'
    issue['body'] += line

  # remove blank entries
  issue['labels'] = filter(bool, issue['labels'])

  if number == "new":

    if issue['assignee'] == '':
      del issue['assignee']
    if issue['milestone'] == '':
      del issue['milestone']
    if issue['body'] == '':
      del issue['body']

    data = ""
    try:
      url = ghUrl("/issues")
      request = urllib2.Request(url, json.dumps(issue))
      data = json.loads(urllib2.urlopen(request).read())
      parens[2] = str(data['number'])
      vim.current.buffer.name = "gissues/" + parens[0] + "/" + parens[1] + "/" + parens[2]
    except urllib2.HTTPError as e:
      if "code" in e and e.code == 410 or e.code == 404:
        print("github-issues.vim: Error creating issue. Do you have a github_access_token defined?")
      else:
        print("github-issues.vim: Unknown HTTP error:")
        print(e)
        print(data)
        print(url)
        print(issue)
  else:
    url = ghUrl("/issues/" + number)
    request = urllib2.Request(url, json.dumps(issue))
    request.get_method = lambda: 'PATCH'
    try:
      urllib2.urlopen(request)
    except urllib2.HTTPError as e:
      if "code" in e and e.code == 410 or e.code == 404:
        print("Could not update the issue as it does not belong to you!")

  if commentmode == 3:
    try:
      url = ghUrl("/issues/" + parens[2] + "/comments")
      data = json.dumps({ 'body': comment })
      request = urllib2.Request(url, data)
      urllib2.urlopen(request)
    except urllib2.HTTPError as e:
      if "code" in e and e.code == 410 or e.code == 404:
        print("Could not post comment. Do you have a github_access_token defined?")

  if commentmode == 3 or number == "new":
    showIssue()

  # mark it as "saved"
  vim.command("setlocal nomodified")

# updates an issues data, such as opening/closing
def setIssueData(issue):
  parens = getFilenameParens()
  url = ghUrl("/issues/" + parens[2])
  request = urllib2.Request(url, json.dumps(issue))
  request.get_method = lambda: 'PATCH'
  urllib2.urlopen(request)

  showIssue()

def getLabels():
  return ghApi("/labels")

def getContributors():
  return ghApi("/stats/contributors")

# adds labels to the match system
def highlightColoredLabels(labels):
  if not labels:
    labels = []

  labels.append({ 'name': 'closed', 'color': 'ff0000'})
  labels.append({ 'name': 'open', 'color': '00aa00'})

  for label in labels:
    vim.command("hi issueColor" + label["color"] + " guifg=#ffffff guibg=#" + label["color"])
    vim.command("let m = matchadd(\"issueColor" + label["color"] + "\", \"\\\\<" + label["name"] + "\\\\>\")")

# queries the ghApi for <endpoint>
def ghApi(endpoint, repourl = False, cache = True):
  global ssl_enabled

  if not repourl:
    repourl = getUpstreamRepoURI()

  if cache and api_cache.get(repourl + "/" + endpoint):
    return api_cache[repourl + "/" + endpoint]

  if not ssl_enabled:
    try:
      import ssl
      ssl_enabled = True
    except:
      print("SSL appears to be disabled or not installed on this machine. Please reinstall Python and/or Vim.")

  try:
    req = urllib2.urlopen(ghUrl(endpoint, repourl), timeout = 5)
    data = json.loads(req.read())

    api_cache[repourl + "/" + endpoint] = data

    return data
  except Exception as e:
    print("github-issues.vim: An error occurred. If this is a private repo, make sure you have a github_access_token defined. Call: " + endpoint + " on " + repourl)
    print(e)
    return None

# generates a github URL, including access token
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
    repourl = getUpstreamRepoURI()

  return vim.eval("g:github_api_url") + "repos/" + urllib2.quote(repourl) + endpoint + params

# returns an array of parens after gissues in filename
def getFilenameParens():
  return vim.current.buffer.name.replace("\\", "/").split("gissues/")[1].split("/")

EOF

function! ghissues#init()
  let g:github_issues_pyloaded = 1
endfunction

" vim: softtabstop=2 expandtab shiftwidth=2 tabstop=2
