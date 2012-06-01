###
# Languages Indicator
# (c) Copyright 2012 Baoshan Sheng
###

$ ->
  bars = $('.code_stats span[data-lang][percent]')
  return unless bars.length
  start_index = bars.length - 1

  do animate = ->
    bar = $ bars[start_index--]
    return unless bar.length
    bar.animate {width: bar.attr('percent')}, 600, 'linear', animate

###
# GitHub Styled File Browser
# (c) Copyright 2012 Baoshan Sheng
###

template = (str) ->
  new Function 'obj',
    'var p=[],print=function(){p.push.apply(p,arguments);};' +
    'with(obj){p.push(\'' +
    str.replace(/[\r\t\n]/g, " ")
       .replace(/'(?=[^<]*%>)/g,"\t")
       .split("'").join("\\'")
       .split("\t").join("'")
       .replace(/<%=(.+?)%>/g, "',$1,'")
       .split('<%').join("');")
       .split('%>').join("p.push('") +
       "');}return p.join('');"

# ## (Underscore) Template for Breadcrumb Navigation
breadcrumb_template = _.template [
  '<% path.forEach(function(dir, i) { %>'
  '<%   if (i < path.length - 1) { %>'
  '<a depth=<%= i %>><%= dir %></a>&nbsp;/&nbsp;'
  '<%   } else { %>'
  '<span><%= dir %></span>'
  '<%   } %>'
  '<% }) %>'
].join ''

# ## (Underscore) Template for File Browser
list_template = template [
  '<div depth="<%= index_depth %>" class="filelist">'
  '<table>'
  '<thead><tr><th></th><th>name</th><th>size</th><th>sloc</th><th>age</th><th>message<div class="history"><a target="_blank" href="https://github.com/<%= user %>/<%= repo %>/commits/master">history</a></div></th></tr></thead>'
  '<tbody>'
  '<% if(index_depth) { %>'
  '<tr class="directory"><td></td><td><a backward>..</a></td><td></td><td></td><td></td><td></td></tr>'
  '<% } %>'
  '<% entries.forEach(function(entry) { %>'
  '<tr class="<%= entry.submodule ? "submodule" : entry.documented ? "document" : entry.type %>">'
  '<td class="icon"></td>'
  '<td><a '
  "<%= entry.type == 'directory' && !entry.submodule ? 'forward' :
    'href=\"' + (entry.submodule ? 'https://github.com/' + entry.submodule : (entry.documented ? (relative_base ? relative_base + '/' : '') + entry.document : 'https://github.com/' + user + '/' + repo + '/blob/master/' + (absolute_base ? absolute_base + '/' : '') + entry.name)) + '\"' %>"
  '<%= entry.type === "file" && !entry.documented ? "target=\'_blank\'": "" %>'
  '><%= entry.name %></a></td>'
  '<td><span><%= entry.type == "file" ? entry.size : "—" %></span></td>'
  '<td><span><%= isNaN(entry.sloc) ? "—" : (entry.sloc + " " + (entry.sloc > 1 ? "lines" : "line")) %></span></td>'
  '<td><%= entry.modified %></td>'
  '<td><div><span><%= entry.subject  %></span><span class="file_browser_author" email="<%= entry.email %>"> [<%= entry.author %>]</span></div></td>'
  '</tr>'
  '<% }); %>'
  '</tbody>'
  '</table>'
  '</div>'
].join ''

gitmodules_cache = {}

process_gitmodules = (gitmodules) ->
  gitmodules = gitmodules.split /\[[^\]]*\]/
  gitmodules = gitmodules[1..]
  gitmodules.reduce (hash, submodule) ->
    match = submodule.match /path = (.*)\n.*url = git(?:@|:\/\/)github\.com(?::|\/)(.*)\.git/
    hash[match[1]] = match[4]
    hash
  , {}

# ## Constructor Arguments
#
# 1. `user`, used to generate correct link for undocumented sources. E.g.,
# `https://github.com/user/repo/blob/master/awesome_file`
# 2. `repo`, also used to generate above link.
# 3. `index_path`, path to `docas.index` file.
# 4. `index_depth`, the depth of the index file, `0` for root directory of the repo.
# 5. `current_depth`, optional, the depth of the current page, defaults to
# `index_depth`.
file_browser = (user, repo, index_path, index_depth = 0, current_depth = index_depth) ->
  
  get_index = ->

    # ### Ajax Call to Get Index
    $.get index_path, (index) ->

      # ## Breadcrumb Navigation
      breadcrumb_path  = index_path.split '/'
      breadcrumb_end   = breadcrumb_path.length - 2
      breadcrumb_start = breadcrumb_end - index_depth + 1
      breadcrumb_path  = breadcrumb_path[breadcrumb_start..breadcrumb_end]

      # ### Render Breadcrumb Navigator
      $('#breadcrumb').html breadcrumb_template
        path: [repo, breadcrumb_path...]

      # ### Handling Breadcrumb Navigation
      $('#breadcrumb a').click ->
        new_depth = $(@).attr('depth') * 1
        new_path = index_path.split '/'
        new_path.splice new_path.length - index_depth + new_depth - 1, index_depth - new_depth
        new file_browser user, repo, new_path.join('/'), new_depth, current_depth

      # ## Content Table

      # `absolute_base` is used to generate github.com links for undocumented sources.
      absolute_base = breadcrumb_path.join '/'

      # `relative_base` is used to generate links for documented sources.
      depth_offset  = index_depth - current_depth
      if depth_offset > 0
        relative_base = breadcrumb_path[breadcrumb_path.length - depth_offset..].join '/'
      else
        relative_base = new Array(-depth_offset + 1).join '../'

      # ### Render Content Table
      table = $ list_template
        user          : user
        repo          : repo
        index_depth   : index_depth
        absolute_base : absolute_base
        relative_base : relative_base
        entries       : process_index index, gitmodules_cache[user + '/' + repo], absolute_base

      update_usernames table

      # ### Handling Folder Navigation
      $(table).find('a[backward]').click ->
        new_path = index_path.split '/'
        new_path.splice new_path.length - 2, 1
        new file_browser user, repo, new_path.join('/'), index_depth - 1, current_depth
      $(table).find('a[forward]').click ->
        new_path = index_path.split '/'
        new_path.splice new_path.length - 1, 0, $(@).html()
        new file_browser user, repo, new_path.join('/'), index_depth + 1, current_depth

      # ### Pushing / Poping the Table
      current_table = $('#filelists div:first-child')[0]
      if current_table
        direction = if index_depth > parseInt $(current_table).attr('depth') then 1 else -1
        width = $(current_table).width() + parseInt $(current_table).css 'margin-right'
        $('#filelists')[if direction < 0 then 'prepend' else 'append'] table
        $(table).css 'margin-left', -width if direction is -1
        $($('#filelists').children()[0]).animate
          'margin-left': (if direction is -1 then 0 else -1) * width
        , 400, 'linear', -> $(current_table).remove()
      else
        $('#filelists').append table

  if gitmodules_cache.hasOwnProperty user + '/' + repo
    get_index()
  else
    gitmodules = index_path.split '/'
    gitmodules = gitmodules[0 .. gitmodules.length - index_depth - 3]
    gitmodules.push 'gitmodules'
    gitmodules = gitmodules.join '/'
    $.ajax
      type: 'GET'
      url: gitmodules
      success: (data) ->
        gitmodules_cache[user + '/' + repo] = process_gitmodules data
        get_index()
      error: ->
        gitmodules_cache[user + '/' + repo] = {}
        get_index()

process_index = (index, gitmodules, base) ->
  lines = index.split('\n').filter((line) -> line)
  entries = []
  lines.forEach (line) ->
    # Sample lines:
    #
    #   "-","57","Mon, 23 Apr 2012 15:40:04 +0800","Me","Initial Commit","<.gitignore>","0","-"
    #   "-","0","Mon, 23 Apr 2012 15:40:04 +0800","Me","Bootstrap","<app.js>","1","0"
    #   "d","204","Fri, 27 Apr 2012 19:50:34 +0800","Me","First Build","<bin>","0","-"
    match = line.match /"(d|-)","(.+)","([^"]+)","(.+)","(.+)","(.+)","<(.+)>","(0|1)","(\d+|-)"/
    return unless match
    entry =
      type       : if match[1] is 'd' then 'directory' else 'file'
      size       : match[2] # filesize((parseInt match[2], 10), on)
      modified   : moment(new Date match[3]).fromNow()
      email      : match[4]
      author     : match[5]
      subject    : match[6]
      name       : match[7]
      documented : match[8] is '1'
      sloc       : parseInt match[9], 10
      submodule  : gitmodules[base + '/' + match[7]]

    # Replace source extension for `.html` to get document file name.
    entry.document = entry.name.replace(/\.[^/.]+$/, '') + '.html' if entry.documented
    # For hidden file without extension.
    entry.document = entry.name + '.html' if entry.document is '.html'
    entries.push entry
  entries.sort (a, b) -> if [a.type, a.name] > [b.type, b.name] then 1 else -1

usernames = {}

update_usernames = (table) ->
  emails = {}
  spans = $(table).find('span[email]')
  for span in spans
    emails[$(span).attr('email')] = null
  for email of emails
    if usernames.hasOwnProperty email
      username = usernames[email]
      if username
        $(table).find('span[email="' + email + '"]').html("[<a href='https://github.com/#{username}'>#{username}</a>]")
    else
      $.getJSON "https://api.github.com/legacy/user/email/#{email}", (data) ->
        username = if data.user then data.user.login else null
        usernames[email] = username
        if username
          $(table).find('span[email="' + email + '"]').html("[<a href='https://github.com/#{username}'>#{username}</a>]")
          

# Expose the constructor globally.
@file_browser = file_browser
