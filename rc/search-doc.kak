provide-module search-doc %~

declare-option str search_doc_command "grep -RHnPo"

# Search kakoune documentation.
define-command search-doc \
    -params 1 \
    -docstring "search-doc <topic>: search kak documentation for a topic" \
    -shell-script-candidates %(
        $kak_opt_search_doc_command '^\*.*[^:](?=::)' "$kak_runtime/doc/"*.asciidoc |
            ruby -e '
                strings_to_delete = ARGV;
                puts STDIN.each_line.map {|line|;
                    everything, file, needle = /^.*\/(\w+)\.asciidoc:\d+:(.*)/.match(line).to_a;
                    strings_to_delete.each {|s| needle.gsub!(s, "")};
                    "#{file}:#{needle}";
                }
            ' "*" "\`" "'"
    ) \
%(
    search-doc-impl "%sh(printf ""%s"" ""${1%%:*}"")" "%sh(printf ""%s"" ""${1#*:}"")"
)

define-command search-doc-impl -hidden -params 2 %(
    doc "%arg(1)"
    execute-keys "/^\Q%sh(echo ""$2"" | sed 's,<,SEARCH_DOC_LT,g; s,>,<gt>,g; s,SEARCH_DOC_LT,<lt>,g')\E<ret>vv"
)

~
