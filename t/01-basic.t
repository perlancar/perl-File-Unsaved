#!perl

use 5.010;
use strict;
use warnings;

use File::Temp qw(tempdir);
use File::Slurp::Tiny qw(write_file);
use File::Unsaved qw(check_unsaved_file);
use Test::More 0.98;

my $dir = tempdir(CLEANUP=>1);
write_file("$dir/a.txt", "");

ok(!check_unsaved_file(path=>"$dir/a.txt"));

subtest "emacs" => sub {
    plan skip_all => "symlink() not available" unless eval { symlink "",""; 1 };
    write_file("$dir/b.txt", "");
    symlink "$dir/b.txt", "$dir/.#b.txt";
    is_deeply(check_unsaved_file(path=>"$dir/b.txt"), {editor=>"emacs"});
};

DONE_TESTING:
done_testing;
