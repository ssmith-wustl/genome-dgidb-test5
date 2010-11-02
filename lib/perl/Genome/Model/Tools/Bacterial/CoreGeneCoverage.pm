package Genome::Model::Tools::Bacterial::CoreGeneCoverage;

use strict;
use warnings;

use Genome;
use Carp;
use IPC::Run;
use File::Slurp;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        fasta_file => { is => 'Scalar',
                             doc => "fasta sequence to check coverage on",
                           },
        pid => { is => 'Scalar',
                 doc => "acceptable percent identity",
                },
        fol => { is => 'Scalar',
                      doc => "fraction of length coverage number",
                },
        option => { is => 'Scalar',
                    doc => "either assembly or geneset",
                  },
        genome => { is => 'Scalar',
                    doc => "either archaea or bact; determines which core gene set/group files to use",
                   },
    ],
    has_optional => [
        bacterial_query_file => {
             is => 'Scalar',
             doc => "200 core genes pep file",
             default => '/gsc/var/lib/blastdb/CoreGenes.faa',
        },
        bacterial_group_file => {
             is => 'Scalar',
             doc => "66 core groups",
             default => '/gscmnt/233/info/seqana/databases/CoreGroups_66.cgf',
        },
        archaea_query_file => {
             is => 'Scalar',
             doc => "archaea core genes pep file",
             default => '/gscmnt/218/info/seqana/species_independant/sabubuck/ARCHAEA/CORE_SET_25/Archaea_coreset_104.gi.faa'
        },
        archaea_group_file => {
                     is => 'Scalar',
             doc => "archaea core groups",
             default => '/gscmnt/218/info/seqana/species_independant/sabubuck/ARCHAEA/CORE_SET_25/Archaea_coreset_104.gi.cgf',
        },
    ],
);

sub help_brief {
"for detecting presence of coregenes/groups in given assembled geneset"
}

sub help_detail {
return <<EOS
for checking genesets or assemblies for coregene/group presence
EOS

}

sub help_synopsis {
return <<EOS
gmt bacterial core-gene-coverage --fasta-file try.pep 
    --genome bact --option assembly --pid 70 --fol 0.7
EOS
}


sub execute {
    my $self = shift;
    $self->status_message("Running core gene coverage command");

    if($self->option eq 'assembly') {
        # xdformat -n -I subj file
        # bsub a tblastn on the subj/query file
        $self->error_message("not implemented yet");
        return 1;
    }
    elsif($self->option eq 'geneset') {
        #looks like we xdformat -p -I the geneset
        my @xdformat = ('xdformat','-p','-I', $self->fasta_file);
        my ($xdf_out,$xdf_err);
        my $xdf_rv = IPC::Run::run(\@xdformat,
                                   '>',
                                   \$xdf_out,
                                   '2>',
                                   \$xdf_err, );
        unless($xdf_rv) {
            $self->error_message("failed to format fasta file ".$self->fasta_file."\n".$xdf_err."\n");
            return 0; # or should we exit(1)?
        }
        # bsub a blastp query on that,
        my ($bsubout,$bsuberr) = ($self->fasta_file.".blastout", $self->fasta_file.".blasterr");
        my $blastresults = $self->fasta_file.".blastp_results";
        my $blast_query_file;
        if($self->genome eq 'bact' ) {
            $blast_query_file = $self->bacterial_query_file;
        }
        elsif($self->genome eq 'archaea' ) 
        {
            $blast_query_file = $self->archaea_query_file;
        }

        $DB::single = 1;
        my $blastp_cmd = join(' ', 'blastp', $self->fasta_file, $blast_query_file, '-o', $blastresults);
        $self->status_message("bsubbing blastp command: $blastp_cmd");
        my $blastp_job = PP::LSF->create(
            command => $blastp_cmd,
            q => 'long',
            o => $bsubout,
            e => $bsuberr,
        );
        my $start_rv = $blastp_job->start;
        confess "Trouble starting LSF job for blastp ($blastp_cmd)" unless defined $start_rv and $start_rv;

        my $wait_rv = $blastp_job->wait_on;
        confess "Trouble while waiting for LSF job for blastp ($blastp_cmd) to complete!" unless defined $wait_rv and $wait_rv;

        $self->status_message("Blastp done, parsing");

        # run parse_blast_results_percid_fraction_oflength on the output
        my @parse = (
                     'gmt','bacterial','parse-blast-results',
                     '--input', $blastresults,
                     '--output', 'Cov_30_PID_30' ,
                     '--num-hits', 1,
                     '--percent', $self->pid,
                     '--fol', $self->fol,
                     '--blast-query', $blast_query_file,
                    );

        my ($parse_stdout, $parse_stderr);
        my $parse_rv = IPC::Run::run(\@parse,
                                     '>',
                                     \$parse_stdout,
                                     '2>',
                                     \$parse_stderr, );
        unless($parse_rv) {
            $self->error_message("failed to parse output ".$blastresults."\n".$parse_stderr);
            return 0;
        }

        $self->status_message("Done parsing, calculating core gene coverage percentage");

        my $core_gene_lines = read_file("Cov_30_PID_30");
        #@core_gene_lines = grep /====/
        my $core_groups_ref_arry = $self->get_core_groups_coverage(
                                                                   $core_gene_lines,
                                                                  );

        # the easy way, but we will have to change it eventually
        my $cmd1 = "grep \"====\" Cov_30_PID_30 | awk '{print \$2}' | sort | uniq | wc -l";
        my $core_gene_count = `$cmd1`;
        my $cmd2 = "grep \">\" ".$blast_query_file." | wc -l"; # counting seqs
        my $query_count = `$cmd2`;
        my $core_groups = scalar(@$core_groups_ref_arry);

        # this doesn't make alot of sense yet.
        my $core_pct = 100 * $core_gene_count / $query_count;
        my $coregene_pct = sprintf("%.02f",100 * $core_gene_count / $query_count);
        
        if($core_pct <= 90) {
            print "Perc of Coregenes present in this assembly: $coregene_pct \%\n";
            #print "FAILED\n";
            print "Number of Core Groups present in this assembly: $core_groups\nCore gene test FAILED\n";
            write_file('CoregeneTest_result', "\nPerc of Coregenes present in this assembly: :$coregene_pct %\nNumber of Core Groups present in this assembly: $core_groups\nCore genetest FAILED\n");

        }
        else
        {
            print "Perc of Coregenes present in this assembly: :$coregene_pct \%\n";
            print "Number of Core Groups present in this assembly: $core_groups\nCore gene test PASSED\n";
            write_file('CoregeneTest_result',"\nPerc of Coregenes present in this assembly: :$coregene_pct \%\nNumber of Core Groups present in this assembly: $core_groups\nCore gene test PASSED\n");

        }

        # the below replicates 'cat Cov_30_PID_30 CoregeneTest_result >Cov_30_PID_30.out
        my $covdata = read_file("Cov_30_PID_30");
        my $cgtest_result = read_file("CoregeneTest_result");
        write_file("Cov_30_PID_30.out",$covdata.$cgtest_result);

        # unlink temp files. these really should be absolute path
        # and should go to a writable directory....
        unlink("Cov_30_PID_30");
        unlink("CoregeneTest_result");
        unlink($blastresults);
        unlink($bsubout);
        unlink($bsuberr);
        unlink($self->fasta_file."xpd");
        unlink($self->fasta_file."xpi");
        unlink($self->fasta_file."xps");
        unlink($self->fasta_file."xpt");
    }
    

    return 1;
}

sub get_core_groups_coverage {
    my $self = shift;
    my $core_groups ;
    if($self->genome eq 'bact') {
        $core_groups = $self->bacterial_group_file;
    }
    elsif($self->genome eq 'archaea') 
    {
        $core_groups = $self->archaea_group_file;
    }
    my $gene_list = shift;
    use IO::String;
    # stolen from  get_core_groups_coverage script
    # altered to 
    #read list to make an array of genes covered

    #my $gene_list=new FileHandle("$options{gene_list}");
    my $gl = IO::String->new($gene_list);
    my %gene_hash;
    while (<$gl>){
        chomp;
        my $line=$_;
        $gene_hash{$line}=1;
    }

    #Output file
#    my $o=new FileHandle("> $options{output}");
    my @results = ( );
    
    #Read ortholog data
    my $cgf=new FileHandle("$core_groups");
    while(<$cgf>){
        chomp;
        my $line=$_;
        $line =~ s/\s+$//;
        my @array=split(/\s/,$line);
        my $flag=0;
        foreach my $a (@array){
            next if ($a eq "-");
            my $gi=(split(/\(/,$a))[0];
            if ($gene_hash{$gi}){
                #print $o "$line\n";
                push(@results, $line);
                last;
            }
        }
    }

#    $o->close;
    return \@results;

}


1;
