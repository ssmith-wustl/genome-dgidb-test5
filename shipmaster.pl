#!/usr/bin/env perl

print "WARNING: this is in development and not ready to run yet.\n*** It will mess with your repo so Ctry-C now. ***\n";

my @c = (
    'git checkout master',
    'git stash',
    'git fetch origin',
    'git pull origin master',
    'git checkout shipit',
    'git pull origin shipit',
    'git merge master',
    ['git status -s | grep ^DD', 'git rm'],
    ['git status -s | grep ^\ U', 'git add'],
    ['git status -s | grep ^AA', 'git rm'],
    ['find lib',  
        qr|lib/perl/Genome/Model/Tools/Music|, 'genome-music/lib/Genome/Model/Tools/Music',
        qr|lib/perl/Genome/Model/Tools|,       'gmt-unsorted/lib/Genome/Model/Tools/',
        qr|lib/perl/Genome/Model/|,            'lib-genome-model/lib/Genome/Model/',
        qr|lib/perl/Genome/Config/|,           'lib-genome-site-wugc-perl',
        qr|lib/perl/Genome/DataSource/|,       'lib-genome-db/lib/Genome/DataSource/', 
        qr|lib/perl/Genome/xsl|,               'lib-genome-model/lib/Genome/xsl'],
    'git add lib',
    'git commit -m "merged master"',
    'git push origin shipit',
    'git checkout master',
    'git stash pop',
);

for my $c (@c) {
    print "\n\n";
    if (ref($c) and @$c == 2) {
        # a command to get files, and a command to run on them
        run_on_files(@$c)
    }
    elsif (ref($c) and @$c > 2) {
        # a command to run get files, a regex to rename
        rename_files(@$c);
    }
    else {
        # a plain command to run
        run($c)
    }
}

sub run_on_files {
    my $f = shift;
    my $c = shift;
    print "FILES: $f\n";
    my @f = `$f`;
    print @f;
    chomp @f;
    if (@f == 0) {
        print "(none)\n";
        return;
    }
    for (@f) {
        s/^..\s+//;
    }
    my $cmd = $c . ' ' . join(" ", map { "'$_'" } @f), "\n";
    run($cmd);
}

sub rename_files {
    my ($cmd_to_get_files, $find, $replace) = @_;
    print "FILES: $cmd_to_get_files\n";
    my @f = `$cmd_to_get_files`;
    print @f;
    chomp @f;
    if (@f == 0) {
        print "(none)\n";
        return;
    }
    while ($find and $replace) {
        print "  RENAME: $find TO: $replace\n";
        for my $o (@f) {
            my $n = $o;
            $n =~ s|$find|$replace|;
            if ($o eq $_) { 

                if (-d $o) {
                    print qq|echo ignoring directory: $_\n|;
                }
                else {
                    print qq|echo "UNKNOWN: $_"\n| 
                }
            } 
            else { 
                if (-d $o) {
                    if (-d $_) {
                        print qq|echo directory exists: $_\n|;
                    }
                    else {
                        print "mkdir $_\n";
                    }
                } 
                else { 
                    print qq|git mv "$o" "$_"\n| 
                }
            }
        }
        # get the next set of expressions
        $find = shift @_;
        $replace = shift @_;
    }
}

sub run {
    my $c = shift;
    print "RUN: $c\n";
    my $a = <>;
    chomp $a;
    if ($a eq 's') {
        print "(skipped)\n";
    }
    elsif ($a eq 'y' or $a eq '') {
        print "(running...)\n";
        my $r = system $c;
        print "exit code $r\n";
    }
    else {
        print "aborting\n";
        exit 1;
    }
}


