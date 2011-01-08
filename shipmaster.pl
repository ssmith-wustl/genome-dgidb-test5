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
    ['git status -s | grep ^AU', 'git rm'],
    ['git status -s | grep ^AA', 'git rm'],
    ['find lib',  qr|lib/perl/Genome/Model/Tools/Music|, 'genome-music/lib/Genome/Model/Tools/Music'],
    ['find lib',  qr|lib/perl/Genome/Model/Tools|,       'gmt-unsorted/lib/Genome/Model/Tools/'],
    ['find lib',  qr|lib/perl/Genome/Model/|,            'lib-genome-model/lib/Genome/Model/'],
    ['find lib',  qr|lib/perl/Genome/Config/|,           'lib-genome-site-wugc-perl'],
    ['find lib',  qr|lib/perl/Genome/DataSource/|,       'lib-genome-db/lib/Genome/DataSource/'], 
    ['find lib',  qr|lib/perl/Genome/xsl|,               'lib-genome-model/lib/Genome/xsl'],
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
    elsif (ref($c) and @$c == 3) {
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
   print "echo @_\n";
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


my @f = `find lib/perl/Genome`;
chomp @f;
if (@f) {
    print "# NEXT THINGS TO RUN:\n";
}
for (@f) {
    chomp; 
    $o = $_; 
    s|lib/perl/Genome/DataSource/|lib-genome-db/lib/Genome/DataSource/|; 
    s|lib/perl/Genome/Model/Tools/Music|genome-music/lib/Genome/Model/Tools/Music|;
    s|lib/perl/Genome/Model/Tools|gmt-unsorted/lib/Genome/Model/Tools/|;
    s|lib/perl/Genome/Model/|lib-genome-model/lib/Genome/Model/|; 
    s|lib/perl/Genome/xsl|lib-genome-model/lib/Genome/xsl|;
    s|lib/perl/Genome/Config/|lib-genome-site-wugc-perl|;
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

