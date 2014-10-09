package File::Unsaved;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(check_unsaved_file);

our %SPEC;

$SPEC{check_unsaved_file} = {
    v => 1.1,
    summary => 'Check whether file has unsaved modification in an editor',
    description => <<'_',

This function tries, using some heuristics, to find out if a file is being
opened and has unsaved modification in an editor. Currently the supported editor
is Emacs.

Return false if no unsaved data is detected, or else a hash structure. Hash will
contain these keys: `editor` (kind of editor).

The heuristics are as folow:

* Emacs: check whether `.#<name>` (symlink) exists.

_
    args => {
        path => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
    },
    result_naked => 1,
};
sub check_unsaved_file{
    require File::Spec;

    my %args = @_;

    my $path = $args{path};
    (-f $path) or die "File does not exist or not a regular file";

    # emacs
    {
        my ($vol, $dir, $file) = File::Spec->splitpath($path);
        my $spath = File::Spec->catpath($vol, $dir, ".#$file");
        if (-l $spath) {
            return {editor=>'emacs'};
        }
    }

    undef;
}

1;
# ABSTRACT: Check whether file has unsaved modification in an editor

=head1 SYNOPSIS

 use File::Unsaved qw(check_file_unsaved);
 die "Can't modify foo.txt because it is being opened and modified in an editor"
     if check_file_unsaved(path => "foo.txt");


=head1 DESCRIPTION


=head1 SEE ALSO

=cut
