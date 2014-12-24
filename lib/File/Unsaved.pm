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
opened and has unsaved modification in an editor. Currently the supported
editors are: Emacs, joe, vim.

The heuristics are as folow:

* Emacs, joe, mc: check whether `.#<name>` symlink exists. Emacs targets the
  symlink to `<user>@<host>.<PID>:<timestamp>` while joe and mc to
  `<user>@<host>.<PID>`. Caveat: Unix only.

* vim: check whether `.<name>.swp` file exists, not older than file, and its
  0x03ef-th byte has the value of `U` (which vim uses to mark the file as
  unsaved). Caveat: vim can be instructed to put swap file somewhere else or not
  create swap file at all, so in those cases unsaved data will not be detected.

_
    args => {
        path => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
        check_pid => {
            summary => 'Whether to check that PID is actually an editor',
            schema  => 'bool*',
            default => 1,
            description => <<'_',

A temporary file might be stale, so checking the existence of temporary file is
not enough. If the temporary file provides pointer to a PID, and this setting is
set to true, will actually check that the PID exists.

_
        },
        check_proc_name => {
            summary => 'Whether to check that process name is actually the '.
                'corresponding editor',
            schema  => 'bool*',
            default => 1,
            description => <<'_',

Is activated only `check_pid` is also 1 and if `Proc::Find` (and thus
`Proc::ProcessTable`) is available.

Might produce a false negative if you happen to rename the editor or use a
differently-named fork/derivative of said editor, although this should be rare.

_
        },
    },
    result_naked => 1,
    result => {
        schema => ['any*', of=>['bool*', 'hash*']],
        description => <<'_',

Return false if no unsaved data is detected, or else a hash structure. Hash will
contain these keys: `editor` (kind of editor, possible values: `emacs`,
`joe/mc`, `joe`, `mc`, `vim`) and might contain these keys: `pid` (PID of
editor), `user`, `host`, `timestamp`.


_
    },
};
sub check_unsaved_file{
    require File::Spec;

    my %args = @_;
    my $check_pid = $args{check_pid} // 1;
    my $check_proc_name = $args{check_proc_name} // 1;
    my $path = $args{path};

    (-f $path) or die "File does not exist or not a regular file";

    my ($vol, $dir, $file) = File::Spec->splitpath($path);

    # emacs & joe/mc
  CHECK1:
    {
        my $spath = File::Spec->catpath($vol, $dir, ".#$file");
        last unless -l $spath;
        my $target = readlink $spath;
        if ($target =~ /\A(.+)\@(.+)\.(\d+):(\d+)\z/) {
            my $res = {editor=>'emacs',
                       user=>$1, host=>$2, pid=>$3, timestamp=>$4};
            if ($check_pid) {
                last CHECK1 unless kill(0, $res->{pid});
                if ($check_proc_name && eval {require Proc::Find; 1}) {
                    last CHECK1 unless Proc::Find::proc_exists(
                        pid => $res->{pid}, name => qr/\b(emacs)\b/,
                    );
                }
            }
            return $res;
        } elsif ($target =~ /\A(.+)\@(.+)\.(\d+)\z/) {
            my $res = {editor=>'joe/mc',
                       user=>$1, host=>$2, pid=>$3};
            if ($check_pid) {
                last CHECK1 unless kill(0, $res->{pid});
                if ($check_proc_name && eval {require Proc::Find; 1}) {
                    my $findres = Proc::Find::proc_find(
                        pid => $res->{pid}, name => qr/\b(joe|mc)\b/);
                    last CHECK1 unless $findres;
                    $res->{editor} = $findres->{name};
                }
            }
            return $res;
        }
    }

    # vim
  CHECK_VIM:
    {
        my $spath = File::Spec->catpath($vol, $dir, ".$file.swp");
        last unless -f $spath;
        last if (-M $spath) > (-M $path); # swap file is older
        open my($fh), "<", $spath or last;
        sysseek $fh, 0x03ef, 0 or last;
        sysread $fh, my($data), 1 or last;
        $data eq 'U' or last;
        return {editor => 'vim'};
    }

    undef;
}

1;
# ABSTRACT:

=head1 SYNOPSIS

 use File::Unsaved qw(check_unsaved_file);
 die "Can't modify foo.txt because it is being opened and modified in an editor"
     if check_unsaved_file(path => "foo.txt");


=head1 DESCRIPTION


=head1 SEE ALSO

=cut
