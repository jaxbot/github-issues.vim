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
import time
import threading

SHOW_ALL = "[Show all issues]"
SHOW_ASSIGNED_ME = "[Only show assigned to me]"

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

colors = {
  "000000": "x016_Grey0",
  "00005f": "x017_NavyBlue",
  "000087": "x018_DarkBlue",
  "0000af": "x019_Blue3",
  "0000d7": "x020_Blue3",
  "0000ff": "x021_Blue1",
  "005f00": "x022_DarkGreen",
  "005f5f": "x023_DeepSkyBlue4",
  "005f87": "x024_DeepSkyBlue4",
  "005faf": "x025_DeepSkyBlue4",
  "005fd7": "x026_DodgerBlue3",
  "005fff": "x027_DodgerBlue2",
  "008700": "x028_Green4",
  "00875f": "x029_SpringGreen4",
  "008787": "x030_Turquoise4",
  "0087af": "x031_DeepSkyBlue3",
  "0087d7": "x032_DeepSkyBlue3",
  "0087ff": "x033_DodgerBlue1",
  "00af00": "x034_Green3",
  "00af5f": "x035_SpringGreen3",
  "00af87": "x036_DarkCyan",
  "00afaf": "x037_LightSeaGreen",
  "00afd7": "x038_DeepSkyBlue2",
  "00afff": "x039_DeepSkyBlue1",
  "00d700": "x040_Green3",
  "00d75f": "x041_SpringGreen3",
  "00d787": "x042_SpringGreen2",
  "00d7af": "x043_Cyan3",
  "00d7d7": "x044_DarkTurquoise",
  "00d7ff": "x045_Turquoise2",
  "00ff00": "x046_Green1",
  "00ff5f": "x047_SpringGreen2",
  "00ff87": "x048_SpringGreen1",
  "00ffaf": "x049_MediumSpringGreen",
  "00ffd7": "x050_Cyan2",
  "00ffff": "x051_Cyan1",
  "5f0000": "x052_DarkRed",
  "5f005f": "x053_DeepPink4",
  "5f0087": "x054_Purple4",
  "5f00af": "x055_Purple4",
  "5f00d7": "x056_Purple3",
  "5f00ff": "x057_BlueViolet",
  "5f5f00": "x058_Orange4",
  "5f5f5f": "x059_Grey37",
  "5f5f87": "x060_MediumPurple4",
  "5f5faf": "x061_SlateBlue3",
  "5f5fd7": "x062_SlateBlue3",
  "5f5fff": "x063_RoyalBlue1",
  "5f8700": "x064_Chartreuse4",
  "5f875f": "x065_DarkSeaGreen4",
  "5f8787": "x066_PaleTurquoise4",
  "5f87af": "x067_SteelBlue",
  "5f87d7": "x068_SteelBlue3",
  "5f87ff": "x069_CornflowerBlue",
  "5faf00": "x070_Chartreuse3",
  "5faf5f": "x071_DarkSeaGreen4",
  "5faf87": "x072_CadetBlue",
  "5fafaf": "x073_CadetBlue",
  "5fafd7": "x074_SkyBlue3",
  "5fafff": "x075_SteelBlue1",
  "5fd700": "x076_Chartreuse3",
  "5fd75f": "x077_PaleGreen3",
  "5fd787": "x078_SeaGreen3",
  "5fd7af": "x079_Aquamarine3",
  "5fd7d7": "x080_MediumTurquoise",
  "5fd7ff": "x081_SteelBlue1",
  "5fff00": "x082_Chartreuse2",
  "5fff5f": "x083_SeaGreen2",
  "5fff87": "x084_SeaGreen1",
  "5fffaf": "x085_SeaGreen1",
  "5fffd7": "x086_Aquamarine1",
  "5fffff": "x087_DarkSlateGray2",
  "870000": "x088_DarkRed",
  "87005f": "x089_DeepPink4",
  "870087": "x090_DarkMagenta",
  "8700af": "x091_DarkMagenta",
  "8700d7": "x092_DarkViolet",
  "8700ff": "x093_Purple",
  "875f00": "x094_Orange4",
  "875f5f": "x095_LightPink4",
  "875f87": "x096_Plum4",
  "875faf": "x097_MediumPurple3",
  "875fd7": "x098_MediumPurple3",
  "875fff": "x099_SlateBlue1",
  "878700": "x100_Yellow4",
  "87875f": "x101_Wheat4",
  "878787": "x102_Grey53",
  "8787af": "x103_LightSlateGrey",
  "8787d7": "x104_MediumPurple",
  "8787ff": "x105_LightSlateBlue",
  "87af00": "x106_Yellow4",
  "87af5f": "x107_DarkOliveGreen3",
  "87af87": "x108_DarkSeaGreen",
  "87afaf": "x109_LightSkyBlue3",
  "87afd7": "x110_LightSkyBlue3",
  "87afff": "x111_SkyBlue2",
  "87d700": "x112_Chartreuse2",
  "87d75f": "x113_DarkOliveGreen3",
  "87d787": "x114_PaleGreen3",
  "87d7af": "x115_DarkSeaGreen3",
  "87d7d7": "x116_DarkSlateGray3",
  "87d7ff": "x117_SkyBlue1",
  "87ff00": "x118_Chartreuse1",
  "87ff5f": "x119_LightGreen",
  "87ff87": "x120_LightGreen",
  "87ffaf": "x121_PaleGreen1",
  "87ffd7": "x122_Aquamarine1",
  "87ffff": "x123_DarkSlateGray1",
  "af0000": "x124_Red3",
  "af005f": "x125_DeepPink4",
  "af0087": "x126_MediumVioletRed",
  "af00af": "x127_Magenta3",
  "af00d7": "x128_DarkViolet",
  "af00ff": "x129_Purple",
  "af5f00": "x130_DarkOrange3",
  "af5f5f": "x131_IndianRed",
  "af5f87": "x132_HotPink3",
  "af5faf": "x133_MediumOrchid3",
  "af5fd7": "x134_MediumOrchid",
  "af5fff": "x135_MediumPurple2",
  "af8700": "x136_DarkGoldenrod",
  "af875f": "x137_LightSalmon3",
  "af8787": "x138_RosyBrown",
  "af87af": "x139_Grey63",
  "af87d7": "x140_MediumPurple2",
  "af87ff": "x141_MediumPurple1",
  "afaf00": "x142_Gold3",
  "afaf5f": "x143_DarkKhaki",
  "afaf87": "x144_NavajoWhite3",
  "afafaf": "x145_Grey69",
  "afafd7": "x146_LightSteelBlue3",
  "afafff": "x147_LightSteelBlue",
  "afd700": "x148_Yellow3",
  "afd75f": "x149_DarkOliveGreen3",
  "afd787": "x150_DarkSeaGreen3",
  "afd7af": "x151_DarkSeaGreen2",
  "afd7d7": "x152_LightCyan3",
  "afd7ff": "x153_LightSkyBlue1",
  "afff00": "x154_GreenYellow",
  "afff5f": "x155_DarkOliveGreen2",
  "afff87": "x156_PaleGreen1",
  "afffaf": "x157_DarkSeaGreen2",
  "afffd7": "x158_DarkSeaGreen1",
  "afffff": "x159_PaleTurquoise1",
  "d70000": "x160_Red3",
  "d7005f": "x161_DeepPink3",
  "d70087": "x162_DeepPink3",
  "d700af": "x163_Magenta3",
  "d700d7": "x164_Magenta3",
  "d700ff": "x165_Magenta2",
  "d75f00": "x166_DarkOrange3",
  "d75f5f": "x167_IndianRed",
  "d75f87": "x168_HotPink3",
  "d75faf": "x169_HotPink2",
  "d75fd7": "x170_Orchid",
  "d75fff": "x171_MediumOrchid1",
  "d78700": "x172_Orange3",
  "d7875f": "x173_LightSalmon3",
  "d78787": "x174_LightPink3",
  "d787af": "x175_Pink3",
  "d787d7": "x176_Plum3",
  "d787ff": "x177_Violet",
  "d7af00": "x178_Gold3",
  "d7af5f": "x179_LightGoldenrod3",
  "d7af87": "x180_Tan",
  "d7afaf": "x181_MistyRose3",
  "d7afd7": "x182_Thistle3",
  "d7afff": "x183_Plum2",
  "d7d700": "x184_Yellow3",
  "d7d75f": "x185_Khaki3",
  "d7d787": "x186_LightGoldenrod2",
  "d7d7af": "x187_LightYellow3",
  "d7d7d7": "x188_Grey84",
  "d7d7ff": "x189_LightSteelBlue1",
  "d7ff00": "x190_Yellow2",
  "d7ff5f": "x191_DarkOliveGreen1",
  "d7ff87": "x192_DarkOliveGreen1",
  "d7ffaf": "x193_DarkSeaGreen1",
  "d7ffd7": "x194_Honeydew2",
  "d7ffff": "x195_LightCyan1",
  "ff0000": "x196_Red1",
  "ff005f": "x197_DeepPink2",
  "ff0087": "x198_DeepPink1",
  "ff00af": "x199_DeepPink1",
  "ff00d7": "x200_Magenta2",
  "ff00ff": "x201_Magenta1",
  "ff5f00": "x202_OrangeRed1",
  "ff5f5f": "x203_IndianRed1",
  "ff5f87": "x204_IndianRed1",
  "ff5faf": "x205_HotPink",
  "ff5fd7": "x206_HotPink",
  "ff5fff": "x207_MediumOrchid1",
  "ff8700": "x208_DarkOrange",
  "ff875f": "x209_Salmon1",
  "ff8787": "x210_LightCoral",
  "ff87af": "x211_PaleVioletRed1",
  "ff87d7": "x212_Orchid2",
  "ff87ff": "x213_Orchid1",
  "ffaf00": "x214_Orange1",
  "ffaf5f": "x215_SandyBrown",
  "ffaf87": "x216_LightSalmon1",
  "ffafaf": "x217_LightPink1",
  "ffafd7": "x218_Pink1",
  "ffafff": "x219_Plum1",
  "ffd700": "x220_Gold1",
  "ffd75f": "x221_LightGoldenrod2",
  "ffd787": "x222_LightGoldenrod2",
  "ffd7af": "x223_NavajoWhite1",
  "ffd7d7": "x224_MistyRose1",
  "ffd7ff": "x225_Thistle1",
  "ffff00": "x226_Yellow1",
  "ffff5f": "x227_LightGoldenrod1",
  "ffff87": "x228_Khaki1",
  "ffffaf": "x229_Wheat1",
  "ffffd7": "x230_Cornsilk1",
  "ffffff": "x231_Grey100",
  "080808": "x232_Grey3",
  "121212": "x233_Grey7",
  "1c1c1c": "x234_Grey11",
  "262626": "x235_Grey15",
  "303030": "x236_Grey19",
  "3a3a3a": "x237_Grey23",
  "444444": "x238_Grey27",
  "4e4e4e": "x239_Grey30",
  "585858": "x240_Grey35",
  "626262": "x241_Grey39",
  "6c6c6c": "x242_Grey42",
  "767676": "x243_Grey46",
  "808080": "x244_Grey50",
  "8a8a8a": "x245_Grey54",
  "949494": "x246_Grey58",
  "9e9e9e": "x247_Grey62",
  "a8a8a8": "x248_Grey66",
  "b2b2b2": "x249_Grey70",
  "bcbcbc": "x250_Grey74",
  "c6c6c6": "x251_Grey78",
  "d0d0d0": "x252_Grey82",
  "dadada": "x253_Grey85",
  "e4e4e4": "x254_Grey89",
  "eeeeee": "x255_Grey93",
}

def distance(rgb1, rgb2):
  r = abs(int(rgb1[:2], 16) - int(rgb2[:2], 16))
  g = abs(int(rgb1[2:4], 16) - int(rgb2[2:4], 16))
  b = abs(int(rgb1[4:6], 16) - int(rgb2[4:6], 16))
  return r + g + b

def hexToTerm(rgb):
  curDist = sys.maxint
  curColor = ""
  curHex = ""

  for key in colors:
    dist = distance(key, rgb)
    if dist < curDist:
      curDist = dist
      curColor = colors[key]
      curHex = key

  return curColor

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
    url = url.split(" ", 1)[0]
    if url.endswith(".git"):
      url = url[:-4]

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
def showIssueList(labels, ignore_cache = False, only_me = False):
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
  issues = getIssueList(repourl, labels, ignore_cache, only_me)

  cur_milestone = str(vim.eval("g:github_current_milestone"))

  # its an array, so dump these into the current (issues) buffer
  for issue in issues:
    if cur_milestone != "" and (not issue["milestone"] or issue["milestone"]["title"] != cur_milestone):
      continue

    issuestr = str(issue["number"]) + " " + issue["title"]

    for label in issue["labels"]:
      issuestr += " [" + label["name"] + "]"

    b.append(issuestr.encode(vim.eval("&encoding")))

  if len(b) < 2:
    b.append("No results found in " + repourl)
  if cur_milestone:
    b.append("Filtering by milestone: " + cur_milestone)
  if labels:
    b.append("Filtering by labels: " + labels)
  if cur_milestone or labels or only_me:
    b.append(SHOW_ALL)
  if not only_me:
    b.append(SHOW_ASSIGNED_ME)

  highlightColoredLabels(getLabels(), True)

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
def getIssueList(repourl, query, ignore_cache = False, only_me = False):
  global github_datacache

  # non-string args correspond to vanilla issues request
  # strings default to label unless they correspond to a state
  params = {}
  if isinstance(query, basestring):
    params = { "labels": query }
  if query in ["open", "closed", "all"]:
    params = { "state": query }
  if only_me:
    params["assignee"] = getCurrentUser()

  return getGHList(ignore_cache, repourl, "/issues", params)

def getCurrentUser():
  return ghApi("", "user", True, False)["login"]

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

  if (ignore_cache or
      github_datacache[repourl].get(endpoint,'') == '' or
      len(github_datacache[repourl].get(endpoint,'')) < 1 or
      time.time() - github_datacache[repourl][endpoint][0]["cachetime"] > 60):

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

    if len(github_datacache[repourl][endpoint]) > 0:
      github_datacache[repourl][endpoint][0]["cachetime"] = time.time()

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
      addToOmni(unicode(label["name"]), 'Label')

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

# handle user pressing enter on the gissue list
# possible actions: view issue, filter by label, filter by assignee, remove filters
def showIssueBuffer(number, url = ""):
  if url != "":
    repourl = url
  else:
    repourl = getUpstreamRepoURI()

  line = vim.eval("getline(\".\")")
  if line == SHOW_ALL:
    showIssueList(0, "True")
    return
  if line == SHOW_ASSIGNED_ME:
    showIssueList(0, "True", "True")
    return

  labels = getLabels()
  if labels is not None:
    for label in labels:
      if str(label["name"]) == number:
        showIssueList(number, "True")
        return

  if number != "new":
    vim.command("normal! 0")
    number = vim.eval("expand('<cword>')")


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
def highlightColoredLabels(labels, decorate = False):
  if not labels:
    labels = []

  labels.append({ 'name': 'closed', 'color': 'ff0000'})
  labels.append({ 'name': 'open', 'color': '00aa00'})

  for label in labels:
    vim.command("hi issueColor" + label["color"] + " guifg=#ffffff guibg=#" + label["color"])
    name = label["name"]
    if decorate:
      name = "\\\\[" + name + "\\\\]"
    else:
      name = "\\\\<" + name + "\\\\>"
    vim.command("let m = matchadd(\"issueColor" + label["color"] + "\", \"" + name + "\")")
  vim.command("hi issueButton guifg=#ffffff guibg=#333333 ctermbg=DarkGray")
  vim.command("let m = matchadd(\"issueButton\", \"\\\\[.*how.*\\\\]\")")

# queries the ghApi for <endpoint>
def ghApi(endpoint, repourl = False, cache = True, repo = True):
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
    req = urllib2.urlopen(ghUrl(endpoint, repourl, repo), timeout = 5)
    data = json.loads(req.read())

    api_cache[repourl + "/" + endpoint] = data

    return data
  except Exception as e:
    if vim.eval("g:gissues_show_errors") != "0":
      print("github-issues.vim: An error occurred. If this is a private repo, make sure you have a github_access_token defined. Call: " + endpoint + " on " + repourl)
      print(e)
    return None

# generates a github URL, including access token
def ghUrl(endpoint, repourl = False, repo = True):
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

  if repo:
    repourl = "repos/" + repourl

  return vim.eval("g:github_api_url") + urllib2.quote(repourl) + endpoint + params

# returns an array of parens after gissues in filename
def getFilenameParens():
  return vim.current.buffer.name.replace("\\", "/").split("gissues/")[1].split("/")

EOF

function! ghissues#init()
  let g:github_issues_pyloaded = 1
endfunction

" vim: softtabstop=2 expandtab shiftwidth=2 tabstop=2
