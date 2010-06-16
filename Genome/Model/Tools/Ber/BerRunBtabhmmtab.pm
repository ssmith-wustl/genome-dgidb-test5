package Genome::Model::Tools::Ber::BerRunBtabhmmtab;

use strict;
use warnings;

use Genome;
use Command;

use Carp;
use Data::Dumper;
use English;

use IO::File;
use IPC::Run;
use File::Copy;
use Time::HiRes qw(sleep);
use File::Slurp;

use Cwd;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is         => 'Command',
    has        => [
        'locus_tag' => {
            is  => 'String',
            doc => "Locus tag for project, containing DFT/FNL postpended",
        },
        'fastadirpath' => {
            is  => 'String',
            doc => "fasta directory path",
        },
        'berdirpath' => {
            is  => 'String',
            doc => "blastp directory path",
        },
        'hmmdirpath' => {
            is  => 'String',
            doc => "hmmpfam directory path",
        },
        'bsubfiledirpath' => {
            is  => 'String',
            doc => "bsub error files directory path",
        },
        'srcdirpath' => {
            is  => 'String',
            doc => "src directory for the ber product naming software",
        },
    ]
);

sub help_brief
{
    "Tool for Running Btab and htap for BER product naming pipeline";
}

sub help_synopsis
{
    return <<"EOS"
      Tool for Running Btab and htab for BER product naming pipeline.
EOS
}

sub help_detail
{
    return <<"EOS"
Tool for Running Btab and htab for BER product naming pipeline.
EOS
}

sub execute
{
    my $self = shift;

    my @berrunbtabhmmtab = $self->gather_details();

    write_file( 'btabdump' . $self->locus_tag, Dumper( \@berrunbtabhmmtab ) );
    my $i = 0;
    foreach my $runs (@berrunbtabhmmtab)
    {
        $i++;

        #print Dumper($runs);

        #print qq{\n\n@$runs\n\n};

#print qq{\n\n$i\n\n};
#IPC::Run::run(@$runs) || croak "\n\nCan't run BerRunBtabhmmtab.pm from BerRunBtabhmmtab.pm: $CHILD_ERROR : $OS_ERROR\n\n" . join(' ', @$runs). "\n$i";
        my $retval = IPC::Run::run(@$runs);
        unless ($retval)
        {
            carp
                "\n\nCan't run BerRunBtabhmmtab.pm from BerRunBtabhmmtab.pm: $CHILD_ERROR : $OS_ERROR\n\n"
                . join( ' ', @$runs )
                . "\n$i running again...";
            sleep(1);
            print Dumper($runs), "\n";
            IPC::Run::run(@$runs)
                || croak
                "\n\nCan't run BerRunBtabhmmtab.pm from BerRunBtabhmmtab.pm: $CHILD_ERROR : $OS_ERROR\n\n"
                . join( ' ', @$runs ) . "\n$i "
                . join( ' ', $runs->[0] ) . "\n";
        }

    }
    print qq{\n\nTotal for Btab/Htab:\t$i\n\n};

    while (1)
    {

        my $berdirpath = $self->berdirpath;
        my $hmmdirpath = $self->hmmdirpath;

        opendir( BERDIR, "$berdirpath" )
            or die
            "Can't open '$berdirpath' ...  from BerRunBtabhmmtab.pm : $OS_ERROR\n";
        my @berfile = readdir(BERDIR);
        closedir(BERDIR);

        my @storageber = ();
        foreach my $bername (@berfile)
        {
            next if $bername =~ m/^\.\.?$/;
            my $btab = qq{.btab};

            if ( $bername =~ /$btab$/ )
            {
                my $bernamecheck = qq{$berdirpath/$bername};

                #if ( (-e $bernamecheck) && (! -z $bernamecheck)) {
                if ( -e $bernamecheck )
                {
                    push( @storageber, $bername );
                }
            }
        }

        my $bercount = $#storageber + 1;

        opendir( HMMDIR, "$hmmdirpath" )
            or die
            "Can't open '$hmmdirpath' ...  from BerRunBtabhmmtab.pm : $OS_ERROR\n";
        my @hmmfile = readdir(HMMDIR);
        closedir(HMMDIR);

        my @storagehmm = ();
        foreach my $hmmname (@hmmfile)
        {
            next if $hmmname =~ m/^\.\.?$/;
            my $htab = qq{.htab};
            if ( $hmmname =~ /$htab$/ )
            {
                my $hmmnamecheck = qq{$hmmdirpath/$hmmname};
                if ( ( -e $hmmnamecheck ) && ( !-z $hmmnamecheck ) )
                {
                    push( @storagehmm, $hmmname );
                }
            }
        }

        my $hmmcount = $#storagehmm + 1;

        my $totalcount = $bercount + $hmmcount;

        unless ( $i == $totalcount )
        {
            sleep 300;
            next;
        }
        else
        {
            sleep 120;
            last;
        }
    }

    return 1;
}

sub gather_details
{
    my $self            = shift;
    my $locus_tag       = $self->locus_tag;
    my $fastadirpath    = $self->fastadirpath;
    my $berdirpath      = $self->berdirpath;
    my $hmmdirpath      = $self->hmmdirpath;
    my $bsubfiledirpath = $self->bsubfiledirpath;
    my $srcdirpath      = $self->srcdirpath;

    my @allipc;
    my $cwd = getcwd();
    unless ( $cwd eq $srcdirpath )
    {
        chdir($srcdirpath)
            or die
            "Failed to change to '$srcdirpath'...  from BerRunBtabhmmtab.pm: $OS_ERROR\n\n";
    }
    opendir( FASTADIR, "$fastadirpath" )
        or die
        "Can't open '$fastadirpath' ...  from BerRunBtabhmmtab.pm: $OS_ERROR\n\n";

    my @fastafile = readdir(FASTADIR);

    closedir(FASTADIR);
    my @fasta_store = ();
    foreach my $fastaname (@fastafile)
    {

        my $fof = qq{fof};

        next if $fastaname =~ m/^\.\.?$/;

        if ( $fastaname =~ /^$locus_tag/ )
        {

            next if $fastaname =~ /$fof$/;

            my $fastanamedir = qq{$fastadirpath/$fastaname};

            if ( -e $fastanamedir )
            {

                push( @fasta_store, $fastaname );

            }
        }
    }

    opendir( BERDIR, "$berdirpath" )
        or die
        "Can't open '$berdirpath' ...  from BerRunBtabhmmtab.pm : $OS_ERROR\n";

    my @berfile = readdir(BERDIR);

    closedir(BERDIR);

    my @ber_store = ();

    foreach my $bername (@berfile)
    {

        next if $bername =~ m/^\.\.?$/;
        my $nr = qq{.nr};

        if ( $bername =~ /$nr$/ )
        {

            my $bernamecheck = qq{$berdirpath/$bername};

            if ( ( -e $bernamecheck ) && ( !-z $bernamecheck ) )
            {

                push( @ber_store, $bername );
            }
        }
    }

    opendir( HMMDIR, "$hmmdirpath" )
        or die
        "Can't open '$hmmdirpath' ...  from BerRunBtabhmmtab.pm : $OS_ERROR\n";

    my @hmmfile = readdir(HMMDIR);

    closedir(HMMDIR);

    my @hmm_store = ();

    foreach my $hmmname (@hmmfile)
    {

        next if $hmmname =~ m/^\.\.?$/;
        my $hmm = qq{.hmmpfam};

        if ( ( $hmmname =~ /$hmm$/ ) )
        {

            my $hmmnamecheck = qq{$hmmdirpath/$hmmname};
            if ( ( -e $hmmnamecheck ) && ( !-z $hmmnamecheck ) )
            {

                push( @hmm_store, $hmmname );

            }
        }
    }

    my $fastacount = 0;
    my $bercount   = 0;
    my $hmmcount   = 0;

    $fastacount = scalar(@fasta_store);
    $bercount   = scalar(@ber_store);
    $hmmcount   = scalar(@hmm_store);

    if ( $fastacount > $bercount )
    {

        die
            qq{\nWARNING, THE PROGRAM HAS STOPPED and Btab run has not started, since your Fasta counts are greater than Ber (Blastp) counts!($fastacount\t$bercount)\n\n};
    }
    elsif ( $fastacount < $bercount )
    {

        die
            qq{\nWARNING, THE PROGRAM  HAS STOPPED and Btab run has not started, since your Ber (Blastp) counts are greater than Fasta counts!($fastacount\t$bercount) \n\n};

    }
    elsif ( $fastacount == $bercount )
    {

        warn
            qq{\nFasta and Ber (Blastp) counts are equal ($fastacount\t$bercount), the program will continue to submit the Btab run, :) \n\n};

    }
    else
    {

        die
            qq{WARNING, THE PROGRAM has STOPPED! PROBLEMS with the bercount.  Btab and Htab have not run\n\n};

    }

    if ( $fastacount > $hmmcount )
    {

        die
            qq{\nWARNING, THE PROGRAM WILL STOP and Htab run has not started, since your Fasta counts are greater than hmmpfam counts!($fastacount\t$hmmcount)\n\n};
    }
    elsif ( $fastacount < $hmmcount )
    {

        die
            qq{\n WARNING, THE PROGRAM WILL STOP and Btab run has not started, since your hmmpfam counts are greater than Fasta counts!($fastacount\t$hmmcount) \n\n};

    }
    elsif ( $fastacount == $hmmcount )
    {

        warn
            qq{\nFasta and hmmpfam counts are equal ($fastacount\t$hmmcount), the program will continue to submit the Htab run, :)\n\n};

    }
    else
    {

        die
            qq{WARNING, THE PROGRAM has STOPPED!  PROBLEMS in the hmmcount.  Btab and Htab have not run\n\n};
    }
    #################################################
    #################################################
    my $btabcount = 0;
    my $htabcount = 0;
    my $datecode  = join( '.', time, $PID );
    my $Rbp       = qq{rusage[mem=4096]};

    #btab send to lsf
    foreach my $btabfile (@ber_store)
    {

        my $btabout = qq{$berdirpath/$btabfile.btab};
        my $btabin  = qq{$berdirpath/$btabfile};
        my $btablog = qq{$srcdirpath/$locus_tag.btab.$datecode.log};
        my $btab    = qq{$srcdirpath/wu-blast2btab.pl};
        my $perlI   = qq{$srcdirpath/lib};

#my $btabcmd     = qq{$perlib $perlI $btab $input $btabin $output $btabout $log $btablog};
        my $bsubbtaberr = qq{$bsubfiledirpath/bsub.err.btab.$btabfile.btab};
        my $bsubbtabout = qq{$bsubfiledirpath/bsub.out.btab.$btabfile.btab};

        my @btabcmd = (
            'perl',    '-I',    $perlI,     $btab,
            '--input', $btabin, '--output', $btabout,
            '--log',   $btablog,
        );

        #my $bsubcmdbb = qq{$bsubbb $obb $ebb $qbb $nbb $Rbb $btabcmd};

        my @bsubcmdb = (
            'bsub',       '-o', $bsubbtabout, '-e',
            $bsubbtaberr, '-q', 'short',      '-n',
            '1',          '-R', $Rbp,         @btabcmd,
        );

        $btabcount++;

        my @btabipc = (

            #\@bsubcmdb,
            \@btabcmd,
            \undef,
            '2>&1',
        );

        push( @allipc, \@btabipc );
    }

    #htab send to lsf
    my $htabinfo = qq{$srcdirpath/hmm_info.txt};
    unless ( -e $htabinfo )
    {
        die
            qq{PROBLEMS with hmm_info.txt at '$srcdirpath'...  from BerRunBtabhmmtab.pm : $OS_ERROR\n\n};
    }

    my @hmmfiles;
HTAB: foreach my $htabfile (@hmm_store)
    {

        my $htabout = qq{$hmmdirpath/$htabfile.htab};

        # create a temp file or something, fill it with a list of files and
        # feed that to hmmToHtab.pl via the -f option.
        # when do we want to enable this?
        #      if(-f $htabout )
        #      {
        #          next HTAB;
        #      }
        push( @hmmfiles, $hmmdirpath . "/" . $htabfile . "\n" );

    }
    write_file( $hmmdirpath . "/" . $locus_tag . ".tablist", @hmmfiles );
    my $htabin  = qq{$hmmdirpath/$locus_tag.htablist};
    my $htablog = qq{$srcdirpath/$locus_tag.htab.$datecode.log};
    my $htab    = qq{$srcdirpath/hmmToHtab.pl};

    #my $htabcmd     = qq{$htab $htabh $htabinfo $htabf $htabin};
    #my $bsubhtaberr = qq{$bsubfiledirpath/bsub.err.htab.$htabfile.htab};
    #my $bsubhtabout = qq{$bsubfiledirpath/bsub.out.htab.$htabfile.htab};
    my $bsubhtaberr = qq{$bsubfiledirpath/bsub.err.htab.$locus_tag.htab};
    my $bsubhtabout = qq{$bsubfiledirpath/bsub.out.htab.$locus_tag.htab};

    my @htabcmd = ( $htab, '-H', $htabinfo, '-f', $htabin, );

    #my $bsubcmdhb = qq{$bsubhb $ohb $ehb $qhb $nhb $Rhb $htabcmd};
    my @bsubcmdh = (
        'bsub',       '-o', $bsubhtabout, '-e',
        $bsubhtaberr, '-q', 'short',      '-n',
        '1',          '-R', $Rbp,         @htabcmd,
    );

    my @htabipc = (

        #\@bsubcmdh,
        \@htabcmd,
        \undef,
        '2>&1',
    );
    push( @allipc, \@htabipc );

    $htabcount++;

    #}

    print
        qq{\n\nSent $btabcount\t wu-blast2btab.pl jobs to lsf from BerRunBtabhmmtab.pm!\n\n};
    print
        qq{\n\nSent $htabcount\thmmToHtab.pl jobs to lsf from BerRunBtabhmmtab.pm!\n\n};

    return @allipc;
}
