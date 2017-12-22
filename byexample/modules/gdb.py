"""
Example:
  (gdb) info files
  (gdb) print 1 + 2
  $1 = 3

"""

import re, pexpect, sys, time
from byexample.parser import ExampleParser
from byexample.finder import MatchFinder
from byexample.interpreter import Interpreter, PexepctMixin

class PythonPromptFinder(MatchFinder):
    target = 'gdb-prompt'

    def example_regex(self):
        return re.compile(r'''
            # Snippet consists of a single prompt line (gdb)
            (?P<snippet>
                (?:^(?P<indent> [ ]*) \(gdb\)[ ]     .*)
            )
            \n?
            # The expected output consists of any non-blank lines
            # that do not start with the prompt
            (?P<expected> (?:(?![ ]*$)     # Not a blank line
                          (?![ ]*\(gdb\))  # Not a line starting with the prompt
                         .+$\n?            # But any other line
                      )*)
            ''', re.MULTILINE | re.VERBOSE)

    def get_language_of(self, *args, **kargs):
        return 'gdb'


class GDBParser(ExampleParser):
    language = 'gdb'

    def example_options_string_regex(self):
        # anything of the form:
        #   #  byexample:  +FOO -BAR +ZAZ=42
        return re.compile(r'#\s*byexample:\s*([^\n\'"]*)$',
                                                    re.MULTILINE)

    def source_from_snippet(self, snippet):
        # remove any option string, gdb does not support
        # comments. If we do not do this, gdb will complain
        snippet = self.example_options_string_regex().sub('', snippet)

        if snippet and not snippet.startswith("(gdb) "):
            raise ValueError("Missing '(gdb)' prompt")

        snippet = snippet[6:]     # remove the (gdb) prompt
        return snippet


class GDBInterpreter(Interpreter, PexepctMixin):
    language = 'gdb'

    def __init__(self, verbosity, encoding):
        self.encoding = encoding

        # --nh     do not read ~/.gdbinit
        # --nx     do not read any .gdbinit
        # --quiet  do not print version number on startup
        PexepctMixin.__init__(self,
                                cmd="/usr/bin/env gdb --nh --nx --quiet",
                                PS1_re = r'\(gdb\)[ ]',
                                any_PS_re = r'')


    def run(self, example, flags):
        if not example.source:
            return ''

        # be extra carefully. if we add an extra newline, gdb
        # will rexecute the last command again.
        if example.source.endswith('\n'):
            source = example.source
        else:
            source = example.source + '\n'

        return self._exec_and_wait(source, timeout=int(flags['TIMEOUT']))

    def initialize(self):
        self._spawn_interpreter()

        # gdb will not print the address of a variable by default
        self._exec_and_wait('set print address off\n')

        # gdb will stop at the first null when printing an array
        self._exec_and_wait('set print null-stop on\n')

    def shutdown(self):
        self._shutdown_interpreter()
