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

def getRepoURI():
	global github_repos

	if "gissues:" in vim.current.buffer.name:
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

def showIssueList():
	repourl = getRepoURI()

	vim.command("silent new")

	b = vim.current.buffer

	if repourl == "":
		b[:] = ["Failed to find a suitable Github repository URL, sorry!"]
		return
	
	b.name = "gissues:/" + repourl + "/issues"

	issues = getIssueList(repourl)

	# its an array, so dump these into the current (issues) buffer
	for issue in issues:
		issuestr = str(issue["number"]) + " " + issue["title"] + " "	

		for label in issue["labels"]:
			issuestr += "#" + label["name"] + " "
			vim.command("hi issueColor" + label["name"] + " guifg=#fff guibg=#" + label["color"])
			vim.command("let m = matchadd(\"issueColor" + label["name"] + "\", \"#" + label["name"] + "\")")

		b.append(issuestr.encode(vim.eval("&encoding")))

	# append leaves an unwanted beginning line. delete it.
	vim.command("1delete _")
	
def getIssueList(repourl):
	global cache_count, github_datacache

	if github_datacache.get(repourl,'') == '' or cache_count > 3:
		upstream_issues = vim.eval("g:github_upstream_issues")
		if upstream_issues == 1:
			# try to get from what repo forked
			data = urllib2.urlopen(ghUrl("/")).read()
			repoinfo = json.loads(data)
			if repoinfo["fork"]:
				pullGithubIssueList(repoinfo["source"]["full_name"])

		pages_loaded = 0

		# load the github API. github_repo looks like "jaxbot/github-issues.vim", for ex.
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
	issues = getIssueList(getRepoURI())
	for issue in issues:
		issuestr = str(issue["number"]) + " " + issue["title"]
		vim.command("call add(b:omni_options, "+json.dumps(issuestr)+")")

def showIssue(number, inplace = False):
	repourl = getRepoURI()

	if not inplace:
		vim.command("silent new")
		vim.current.buffer.name = "gissues:/" + repourl + "/" + number

	b = vim.current.buffer

	if number == "new":
		# new issue
		issue = { 'title': '',
			'body': '',
			'number': 'new',
			'user': {
				'login': ''
			},
			'assignee': '',
		}
	else:
		url = ghUrl("/issues/" + number)
		issue = json.loads(urllib2.urlopen(url).read())

	b.append("# " + issue["title"].encode(vim.eval("&encoding")) + " (" + str(issue["number"]) + ")")
	if issue["user"]["login"]:
		b.append("## Reported By: " + issue["user"]["login"].encode(vim.eval("&encoding")))

	b.append("## State: " + issue["state"])

	if issue["assignee"]:
		b.append("## Assignee: " + issue["assignee"].encode(vim.eval("&encoding")))
	b.append(issue["body"].encode(vim.eval("&encoding")).split("\n"))

	if number != "new":
		b.append("## Comments")

		if issue["comments"] > 0:
			url = ghUrl("/issues/" + number + "/comments")
			data = urllib2.urlopen(url).read()
			comments = json.loads(data)

			if len(comments) > 0:
				for comment in comments:
					b.append("")
					b.append(comment["user"]["login"].encode(vim.eval("&encoding")) + "(" + comment["created_at"] + ")")
					b.append(comment["body"].encode(vim.eval("&encoding")).split("\n"))
		
		else:
			b.append("")
			b.append("No comments.")
			b.append("")
	
		b.append("## Add a comment")
		b.append("")
	
	vim.command("set ft=markdown")

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
			else:
				issue['state'] = "open"
			continue

		assignee = line.split("## Assignee: ")
		if len(assignee) > 1:
			issue['assignee'] = assignee
			continue

		if issue['body'] != '':
			issue['body'] += '\n'
		issue['body'] += line
	
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
		updateGissue()

	# mark it as "saved"
	vim.command("setlocal nomodified")

def updateGissue():
	parens = vim.current.buffer.name.split("/")

	vim.command("normal ggdG")
	showIssue(parens[3], True)
	vim.command("normal ggddG")

	# mark it as "saved"
	vim.command("setlocal nomodified")

def setIssueData(issue):
	parens = vim.current.buffer.name.split("/")
	url = ghUrl("/issues/" + parens[3])
	request = urllib2.Request(url, json.dumps(issue))
	request.get_method = lambda: 'PATCH'
	urllib2.urlopen(request)

	updateGissue()

def ghUrl(endpoint):
	params = ""
	token = vim.eval("g:github_access_token")
	if token:
		params = "?access_token=" + token
	return vim.eval("g:github_api_url") + "repos/" + urllib2.quote(getRepoURI()) + endpoint + params
EOF

function! ghissues#init()
	let g:github_issues_pyloaded = 1
endfunction

