" core is written in Python for easy JSON/HTTP support " do not continue if Vim is not compiled with Python2.7 support
if !has("python")
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

# since Vim is single threaded, we cheat a little and track the current state
current_repo = ""
current_issues = []

def getRepoURI():
	global current_repo, github_repos

	# get the directory the current file is in
	filepath = vim.eval("shellescape(expand('%:p:h'))")

	# cache the github repo for performance
	if github_repos.get(filepath,'') != '':
		current_repo = github_repos[filepath]
		return

	cmd = '(cd ' + filepath + ' && git remote -v)'

	filedata = os.popen(cmd).read()

	current_repo = ""

	# possible URLs
	urls = vim.eval("g:github_issues_urls")
	for url in urls:
		s = filedata.split(url)
		if len(s) > 1:
			s = s[1].split()[0].split(".git")
			github_repos[filepath] = s[0]
			current_repo = s[0]
			break
	
def pullGithubIssueList():
	global current_repo, current_issues, cache_count, github_datacache

	# nothing found? can't continue
	if current_repo == "":
		return
	
	if github_datacache.get(current_repo,'') == '' or cache_count > 3:
		params = ""
		token = vim.eval("g:github_access_token")
		if token != "":
			params = "?access_token=" + token
		upstream_issues = vim.eval("g:github_upstream_issues")
		if upstream_issues == 1:
			# try to get from what repo forked
			data = urllib2.urlopen(vim.eval("g:github_api_url") + "repos/" + urllib2.quote(current_repo) + params).read()
			repoinfo = json.loads(data)
			if repoinfo["fork"]:
				current_repo = repoinfo["source"]["full_name"]
				pullGithubIssueList()

		pages_loaded = 0
		# load the github API. github_repo looks like "jaxbot/github-issues.vim", for ex.
		url = vim.eval("g:github_api_url") + "repos/" + urllib2.quote(current_repo) + "/issues" + params
		try:
			github_datacache[current_repo] = []
			while pages_loaded < int(vim.eval("g:github_issues_max_pages")):
				response = urllib2.urlopen(url)
				# JSON parse the API response, add page to previous pages if any
				github_datacache[current_repo] += json.loads(response.read())
				pages_loaded += 1
				headers = response.info() # try to find the next page
				if 'Link' not in headers:
					break
				next_url_match = re.match(r"<(?P<next_url>[^>]+)>; rel=\"next\"", headers['Link'])
				if not next_url_match:
					break
				url = next_url_match.group('next_url')
		except urllib2.URLError as e:
			github_datacache[current_repo] = []
		except urllib2.HTTPError as e:
			if e.code == 410:
				github_datacache[current_repo] = []
		cache_count = 0
	else:
		cache_count += 1

	current_issues = github_datacache[current_repo]

def pullGithubIssue():
	global current_repo

	# nothing found? can't continue
	if current_repo == "":
		return
	
	params = ""
	token = vim.eval("g:github_access_token")
	if token != "":
		params = "?access_token=" + token
	
	number = vim.eval("expand('<cword>')")

	# load the github API. github_repo looks like "jaxbot/github-issues.vim", for ex.
	url = vim.eval("g:github_api_url") + "repos/" + urllib2.quote(current_repo) + "/issues/" + number + params
	data = urllib2.urlopen(url).read()

	vim.command("edit github://issues/"+number)
	vim.command("set buftype=nofile")
	vim.command("normal ggdG")

	# JSON parse the API response
	issue = json.loads(data)
	# its an array, so dump these into the current (issues) buffer
	vim.current.buffer.append("#" + str(issue["number"]) + " " + issue["title"].encode(vim.eval("&encoding")))
	vim.current.buffer.append("==================================================")
	vim.current.buffer.append("Reported By: " + issue["user"]["login"].encode(vim.eval("&encoding")))
	vim.current.buffer.append("")
	vim.current.buffer.append(issue["body"].encode(vim.eval("&encoding")).split("\n"))
	vim.current.buffer.append("")

	if issue["comments"] > 0:
		url = vim.eval("g:github_api_url") + "repos/" + urllib2.quote(current_repo) + "/issues/" + number + "/comments" + params
		data = urllib2.urlopen(url).read()
		comments = json.loads(data)

		if len(comments) > 0:
			vim.current.buffer.append("Comments")
			vim.current.buffer.append("==================================================")
			for comment in comments:
				vim.current.buffer.append("")
				vim.current.buffer.append(comment["user"]["login"].encode(vim.eval("&encoding")))
				vim.current.buffer.append("--------------------------------------------------")
				vim.current.buffer.append(comment["body"].encode(vim.eval("&encoding")).split("\n"))

	# append leaves an unwanted beginning line. delete it.
	vim.command("1delete _")

def dumpIssuesIntoBuffer():
	global current_repo, current_issues

	if current_repo == "":
		vim.current.buffer[:] = ["Failed to find a suitable Github remote, sorry!"]
		return

	# its an array, so dump these into the current (issues) buffer
	for issue in current_issues:
		issuestr = str(issue["number"]) + " " + issue["title"]
		vim.current.buffer.append(issuestr.encode(vim.eval("&encoding")))

	# append leaves an unwanted beginning line. delete it.
	vim.command("1delete _")

def populateOmniComplete():
	global current_repo, current_issues
	for issue in current_issues:
		issuestr = str(issue["number"]) + " " + issue["title"]
		vim.command("call add(b:omni_options, "+json.dumps(issuestr)+")")

EOF

function! ghissues#init()
	let g:github_issues_pyloaded = 1
endfunction

