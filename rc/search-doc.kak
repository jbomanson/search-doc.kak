provide-module search-doc %~

# Search kakoune documentation.
define-command search-doc \
    -params 1 \
    -docstring "search-doc <topic>: search kak documentation for a topic" \
    -shell-script-candidates %(
        ag -o '^\*.*(?=::)' "$kak_runtime/doc" |
            ruby -e '
                '"
                def escape(string)
                    \"'#{string.gsub(\"'\", \"''\")}'\"
                end
                "'
                strings_to_delete = ARGV;
                puts STDIN.each_line.map {|line|;
                    everything, file, needle = /^.*\/(\w+)\.asciidoc:\d+:(.*)/.match(line).to_a;
                    strings_to_delete.each {|s| needle.gsub!(s, "")};
                    "#{file} #{escape(needle)}";
                }
            ' "::" "*" "\`" "'"
    ) \
%(
    evaluate-commands search-doc-impl %arg(1)
)

define-command search-doc-impl -hidden -params .. %(
    doc "%arg(1)"
    execute-keys "/^\Q%sh(shift; echo $@ | sed 's,<,SEARCH_DOC_LT,g; s,>,<gt>,g; s,SEARCH_DOC_LT,<lt>,g')\E<ret>vv"
)

~
