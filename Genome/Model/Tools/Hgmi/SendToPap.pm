package Genome::Model::Tools::Hgmi::SendToPap;

use strict;
use warnings;

use Genome;
use Command;
use Carp;

use Bio::SeqIO;
use Bio::Seq;
use Bio::DB::BioDB;
use Bio::DB::Query::BioQuery;

use File::Slurp;
use File::Temp qw/ tempfile tempdir /;
use DateTime;
use List::MoreUtils qw/ uniq /;
use IPC::Run;
use Workflow::Simple;
use Data::Dumper;


UR::Object::Type->define(
    class_name => __PACKAGE__,
    is         => 'Command',
    has        => [
        'locus_tag' => {
            is  => 'String',
            doc => "taxonomy name"
        },
        'sequence_set_id' => {
            is  => 'Integer',
            doc => "Sequence set id in MGAP database",
        },
	'sequence_name' => {
	    is  => 'String',
	    doc => "assembly name in MGAP database",
	},
	'organism_name' => {
	    is  => 'String',
	    doc => 'organism name in MGAP database',
	},
        'taxon_id' => {
            is  => 'Integer',
            doc => "NCBI Taxonomy id",
            is_optional => 1,
        },
        'workflow_xml' => {
            is => 'String',
            doc => "Workflow xml file",
            is_optional => 1,
        },
        'keep_pep' => {
            is          => 'Boolean',
            doc         => "keep temporary fasta file of gene proteins",
            is_optional => 1,
            default     => 0
        },
        'pep_file' => {
            is          => 'String',
            doc         => "fasta file of gene proteins",
            is_optional => 1,
        },
        'dev' => {
            is => 'Boolean',
            doc => "use development databases",
            is_optional => 1,
        },
        'chunk_size' => {
            is => 'Integer',
            doc => "Chunk size parameter for PAP (default 10)",
            is_optional => 1,
            default => 10,
        },
        'gram_stain' => {
            is => 'String',
            doc => 'Gram Stain',
            valid_values => ['positive','negative']
        },
        'blastp_archive_dir' => {
                                 is  => 'String',
                                 doc => 'blastp raw output archive directory',
                             },
        'interpro_archive_dir' => {
                                   is  => 'String',
                                   doc => 'intepro raw output archive directory',
                               },
        'keggscan_archive_dir' => {
                                   is  => 'String',
                                   doc => 'keggscan raw output archive directory',
                               },
        'resume_workflow' => { 
                              is => 'String',
                              doc => 'resume (crashed) workflow from previous invocation',
			      is_optional => 1,
                             },
        'no_load_biosql' => {
                             is => 'Boolean',
                             doc => 'Skip loading biosql',
                             is_optional => 1,
                             default => 0,
                            },

    ]
);

sub help_brief
{
    "Bridges between HGMI tools and PAP";
}

sub help_synopsis
{
    return <<"EOS"
Bridges between HGMI tools and PAP.  This tool pulls data from biosql,
then initializes and runs the PAP workflow.
EOS
}

sub help_detail
{
    return <<"EOS"
Bridges between HGMI tools and PAP.  This tool loads predictions from mgap to
biosql, pulls data from biosql, then initializes and runs the PAP workflow.
EOS
}

sub execute
{
    my $self = shift;

    my $gram_stain = $self->gram_stain();

    unless (($gram_stain eq 'positive') || ($gram_stain eq 'negative')) {
        die "gram_stain must be 'positive' or 'negative', not '$gram_stain'";
    }
    
    my $previous_workflow_id = $self->resume_workflow();
    # start timer here
    my $starttime = DateTime->now(time_zone => 'America/Chicago');
    unless (defined($previous_workflow_id)) {
        print STDERR "moving data from mgap to biosql SendToPap.pm\n";
        $self->mgap_to_biosql();

        print STDERR "creating peptide file SendToPap.pm\n";
        $self->get_gene_peps();
    }
    
    # interface to workflow to start the PAP.
    $self->do_pap_workflow();

    # end timer, log run time
    my $finishtime = DateTime->now(time_zone => 'America/Chicago');
    my $runtime = ($finishtime->epoch() - $starttime->epoch());
    $self->activity_log($runtime,$self->locus_tag );

    return 1;
}

sub get_gene_peps
{
    my $self = shift;
    # this needs to handle switching to
    # either dev or prod
    my $dbadp;

    if($self->dev())
    {
        $dbadp = Bio::DB::BioDB->new(
            -database => 'biosql',
            -user     => 'sg_user',
            -pass     => 'sgus3r',
            -dbname   => 'DWDEV',
            -driver   => 'Oracle'
        );
    }
    else
    {
        $dbadp = Bio::DB::BioDB->new(
            -database => 'biosql',
            -user     => 'sg_user',
            -pass     => 'sg_us3r',
            -dbname   => 'DWRAC',
            -driver   => 'Oracle'
        );
    }

    my $cleanup = $self->keep_pep ? 0 : 1;
    my $tempdir = tempdir( 
                          CLEANUP => $cleanup,
                          DIR     => '/gscmnt/temp212/info/annotation/PAP_tmp',
                         );
    my ( $fh, $file ) = tempfile(
        "pap-XXXXXX",
        DIR    => $tempdir,
        SUFFIX => '.fa'
    );
    #print "tempdir: ", $tempdir, ", tempfile: ", $file, ", cleanup: ",
    #    $cleanup, "\n";
    unless(defined($self->pep_file))
    {
        $self->pep_file($file);
    }
    $file = $self->pep_file();
    my $seqout = new Bio::SeqIO(
        -file   => ">$file",
        -format => "fasta"
    );

    my $adp = $dbadp->get_object_adaptor("Bio::SeqI");

    $adp->dbh->{'LongTruncOk'} = 0;
    $adp->dbh->{'LongReadLen'} = 1000000000;

    my $query = Bio::DB::Query::BioQuery->new();
    $query->datacollections( [ "Bio::PrimarySeqI s", ] );

    my $locus_tag = $self->locus_tag;
    $query->where( ["s.display_id like '$locus_tag%'"] );
    my $res = $adp->find_by_query($query);
GENE: while ( my $seq = $res->next_object() )
    {
        my $gene_name = $seq->display_name();

        #print $gene_name, "\n";
        my @feat = $seq->get_SeqFeatures();
        foreach my $f (@feat)
        {
            my $display_name = $f->display_name();
            #print STDERR $display_name," ", $f->primary_tag,"\n";
            next GENE if $f->primary_tag ne 'gene';
            next if $f->has_tag('Dead');
            my $ss;
            $ss = $seq->subseq( $f->start, $f->end );

            unless(defined($ss)) { 
                die "failed to fetch sequence for '$display_name' from BioSQL";
            }
            
            my $pep = $self->make_into_pep( $f->strand,
                $ss,
                #$seq->subseq($f->start,$f->end),
                $display_name );
            $seqout->write_seq($pep);
            #print STDERR "sequence should be written out\n";
        }
    }
    if(! -f $file )
    {
        print STDERR "the fasta file $file doesn't exist! SendToPap.pm\n";
        return 0;
    }
    unless( -s $file > 0 )
    {
        print STDERR "the fasta file $file still empty! SendToPap.pm\n";
    }

    return 1;
}

sub make_into_pep
{
    my ( $self, $strand, $subseq, $name ) = @_;

    my $seq = new Bio::Seq(
        -display_id => $name,
        -seq        => $subseq
    );
    my $newseq;
    if ( $strand < 0 )
    {
        $newseq = $seq->revcom->translate->seq;
    }
    else
    {
        $newseq = $seq->translate->seq;
    }
    my $seqobj = new Bio::Seq(
        -display_id => $name,
        -seq        => $newseq
    );
    return $seqobj;
}

sub mgap_to_biosql
{
    my $self      = shift;
    my $locus_tag = $self->locus_tag;
    my $ssid      = $self->sequence_set_id;
    my $taxid     = $self->taxon_id;
    my $testnorun = shift;
    my @command = (
        'bap_load_biosql', '--sequence-set-id', $ssid,
        #'--tax-id',        $taxid,
    );

    if(defined($taxid))
    {
        push(@command, '--tax-id');
        push(@command, $taxid);
    }

    if($self->dev)
    {
        push(@command,'--dev');
        push(@command,'--biosql-dev');
    }
    my ($cmd_out,$cmd_err);

    if($testnorun)
    {
        # just for testing.
        print join(" " , @command),"\n";;
        return 1;
    }

    if(! $self->no_load_biosql)
    {
        IPC::Run::run(
            \@command,
            \undef,
            '>',
            \$cmd_out,
            '2>',
            \$cmd_err,
        ) or croak "can't load biosql from mgap!!!\n$cmd_err SendToPap.pm";

        print STDERR $cmd_err,"\n";
    }
    return 1;

}

## need workflow item here...

sub do_pap_workflow
{
    my $self = shift;

    my $xml_file = $self->workflow_xml;
    my $fasta_file = $self->pep_file;
    my $chunk_size = $self->chunk_size;
    #print STDERR "\n",$xml_file,"\n";
    #print STDERR "\nfasta file is ",$fasta_file,"\n";

    my $previous_workflow_id = $self->resume_workflow();
   
    unless (defined($previous_workflow_id)) {
    
        if (! -f $fasta_file) {
            print STDERR "\nwhere is the fasta file ", $fasta_file, "? SendToPap.pm\n";
            croak "fasta file doesn't exist! SendToPap.pm";
        }
    
    }

    my $workflow_dev_flag = 0;

    if ($self->dev()) { $workflow_dev_flag = 1; }

    my $output;

    if (defined($previous_workflow_id)) {

        $output = resume_lsf($previous_workflow_id);

    }

    else {
        if($xml_file =~ /noblastp/)
        {
            #print STDERR "skipping blastp in PAP.\n";
            $self->status_message("skipping blastp in PAP");
            $output = run_workflow_lsf(
                                       $xml_file,
                                       'fasta file'           => $fasta_file,
                                       'chunk size'           => 1000,
                                       'dev flag'             => $workflow_dev_flag,
                                       'biosql namespace'     => 'MGAP',
                                       'gram stain'           => $self->gram_stain(),
                                       'interpro archive dir' => $self->interpro_archive_dir(),
                                       'keggscan archive dir' => $self->keggscan_archive_dir(),
                                      );

        }
        else
        { 
            $output = run_workflow_lsf(
                                       $xml_file,
                                       'fasta file'           => $fasta_file,
                                       'chunk size'           => $self->chunk_size(),
                                       'dev flag'             => $workflow_dev_flag,
                                       'biosql namespace'     => 'MGAP',
                                       'gram stain'           => $self->gram_stain(),
                                       'blastp archive dir'   => $self->blastp_archive_dir(),
                                       'interpro archive dir' => $self->interpro_archive_dir(),
                                       'keggscan archive dir' => $self->keggscan_archive_dir(),
                                      );
        }

    }

    
    # do quick check on the return value.
    #print STDERR Dumper($output),"\n";
   
    if (defined($output)) {
        print STDERR "workflow completed successfully ... SendToPap.pm\n";
        return 0;
    }
    else {
        
        foreach my $error (@Workflow::Simple::ERROR) {
 
            print STDERR join("\t", 
                              $error->dispatch_identifier(),
                              $error->name(), 
                              $error->start_time(), 
                              $error->end_time(),
                              $error->exit_code(),
                             ), "\n";

            print STDERR $error->stdout(), "\n";
            print STDERR $error->stderr(), "\n";

        }
    
        return 1;

    }

}


sub activity_log
{
    my $self = shift;
    my ($run_time, $locus_tag) = @_;
    my $sequence_id   = $self->sequence_set_id;
    my $organism_name = $self->organism_name;
    my $sequence_name = $self->sequence_name;

    if($self->dev)
    {
        return 1;

    }
    #use BAP::DB::Organism;
    #my ($organism) = BAP::DB::Organism->search({locus => $locus_tag});
    #my $organism_name;
    #if($organism)
    #{
    #    $organism_name = $organism->organism_name;
    #}
    #else
    unless ($organism_name)
    {
        carp "Couldn't get organism name for activity logging, will continue logging with locus tag, instead ... from SendToPap.pm\n";
        $organism_name = $locus_tag;
    }
    $locus_tag =~ s/(DFT|FNL|MSI)$//;
    my $db_file = '/gscmnt/temp212/info/annotation/BAP_db/mgap_activity.db';
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file",'','',
                           {RaiseError => 1, AutoCommit => 1});
    unless(defined($dbh))
    {
        return 0;
    }
    my $sql = <<SQL;
    INSERT INTO activity_log (activity,
                              sequence_id,
                              sequence_name,
                              organism_name,
                              host,
                              user,
                              started,
                              finished)
        VALUES (?,?,?,?,?,?,
                strftime('%s', 'now') - $run_time,
                strftime('%s', 'now')
        );
SQL

    my $host = undef;
    my $user = undef;

    if (exists($ENV{LSB_HOSTS}) )
    {
        $host = $ENV{LSB_HOSTS};
    }
    elsif (exists($ENV{HOST}) )
    {
        $host = $ENV{HOST};
    }

    if (exists($ENV{USER}) )
    {
        $user = $ENV{USER};
    }
    elsif (exists($ENV{LOGIN}) )
    {
        $user = $ENV{LOGIN};
    }
    elsif (exists($ENV{USERNAME}) )
    {
        $user = $ENV{USERNAME};
    }


    if(!$self->dev)
    {

        $dbh->do($sql, {},
                 'protein annotation',$sequence_id,$sequence_name,
                 $organism_name,
                 $host, $user);

    }
    return 1;
}

1;

# $Id$
