if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Issue keys (PROJ-123, ABC-456, etc.)
syntax match jiraIssueKey '\<[A-Z]\+[A-Z0-9]*-[0-9]\+\>'

" Status indicators
syntax match jiraStatus '\<\(To Do\|In Progress\|Done\|Closed\|Resolved\|Open\|Reopened\|In Review\)\>'

" Priority levels
syntax match jiraPriority '\<\(Highest\|High\|Medium\|Low\|Lowest\|Critical\|Major\|Minor\|Trivial\)\>'

" Issue types
syntax match jiraIssueType '\<\(Bug\|Task\|Story\|Epic\|Sub-task\|Improvement\|New Feature\)\>'

" User mentions and assignments
syntax match jiraUser '@[a-zA-Z0-9._-]\+'
syntax match jiraAssignee 'Assignee:\s*\zs.*$'
syntax match jiraReporter 'Reporter:\s*\zs.*$'

" Dates and times
syntax match jiraDate '\d\{4\}-\d\{2\}-\d\{2\}'
syntax match jiraDateTime '\d\{4\}-\d\{2\}-\d\{2\}T\d\{2\}:\d\{2\}:\d\{2\}'

" Labels and components
syntax match jiraLabel '\<\(Labels\|Components\):\s*\zs.*$'

" Headers and sections
syntax match jiraHeader '^[A-Z][A-Z ]*:\s*'
syntax match jiraSection '^\s*[─┌┐└┘│├┤┬┴┼]\+.*$'
syntax match jiraSeparator '^\s*[─═]\{5,\}.*$'

" Comments section
syntax match jiraCommentHeader '^Comments:\s*$'
syntax match jiraCommentMeta '^\s*\[.*\]\s*-\s*.*$'

" URLs and links
syntax match jiraUrl 'https\?://[^\s]\+'

" Markdown-like formatting in descriptions
syntax match jiraBold '\*\*[^*]\+\*\*'
syntax match jiraItalic '\*[^*]\+\*'
syntax match jiraCode '`[^`]\+`'

" Fields with values
syntax match jiraFieldName '^\s*[A-Za-z ]\+:\s*' contains=jiraFieldColon
syntax match jiraFieldColon ':' contained

" Define highlighting
highlight default link jiraIssueKey Identifier
highlight default link jiraStatus Statement
highlight default link jiraPriority Special
highlight default link jiraIssueType Type
highlight default link jiraUser PreProc
highlight default link jiraAssignee String
highlight default link jiraReporter String
highlight default link jiraDate Number
highlight default link jiraDateTime Number
highlight default link jiraLabel Tag
highlight default link jiraHeader Title
highlight default link jiraSection Comment
highlight default link jiraSeparator Comment
highlight default link jiraCommentHeader Title
highlight default link jiraCommentMeta Comment
highlight default link jiraUrl Underlined
highlight default link jiraBold Bold
highlight default link jiraItalic Italic
highlight default link jiraCode String
highlight default link jiraFieldName Label
highlight default link jiraFieldColon Delimiter

let b:current_syntax = "jira"

let &cpo = s:cpo_save
unlet s:cpo_save