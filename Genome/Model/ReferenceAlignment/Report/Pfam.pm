#:eclark Has hardcoded path to iprscan, huge chunks of commented out code thats not clear what 
# it was doing or what its still there for.  A simple line by line refactor of the module would 
# make it a lot more clear.

package Genome::Model::ReferenceAlignment::Report::Pfam;

use strict;
use warnings;

use Genome;
use CGI;
use English;
use Memoize;
use IO::File;
use Cwd;
use File::Basename qw/basename/;
use File::Slurp;
use List::MoreUtils qw/ uniq /;
use App::Report;
use IPC::Run;

class Genome::Model::ReferenceAlignment::Report::Pfam{
    is => 'Genome::Model::Report',
    has => [ 'test_no_load' => { is          => 'BOOLEAN',
                                 is_optional => 1,
                                 default     => 0, 
                               }, 
           ],
};

sub _add_to_report_xml {
    my $self = shift;

    return {
        html => $self->generate_report_detail,
    };
}

sub name { return 'Pfam'; }
sub description 
{
    my $self=shift;
    my $model = $self->model;
    #my $output_file =  $self->report_brief_output_filename;
    
    #my $brief = IO::File->new(">$output_file");
    #die unless $brief;

    #my $desc = "Gold Snp coverage for " . $model->name . " as of " . UR::Time->now;
    #$brief->print("<div>$desc</div>");
    #$brief->close;

    return '<div>Pfam report for ' . $model->name . " as of " . UR::Time->now . '</div>';
}

sub _call {
    my ($self, $cmd, @params) = @_;
    print STDERR "RUNNING: " . join(" ",$cmd,@params) . "\n";
    my ($stdout,$stderr);
    my $retval = IPC::Run::run( [ $cmd, @params ],
                                '>',
                                \$stdout,
                                '2>',
                                \$stderr,
                              ) or die "failed to run $cmd! \n$stderr\n";

#or die " failed to run $cmd!($retval)\nparams were" . Data::Dumper::Dumper(\@params) . "\nstderr:\n" .$stderr ."\n";

    if (wantarray) {
        my @lines = split(/\n/,$stdout);
        return @lines;
    }
    else {
        return $stdout;
    }
}

sub status_message {
    my ($self,$msg) = @_;
    chomp $msg;
    print STDERR "STATUS: $msg\n";
}


sub generate_report_detail 
{
    # TODO this does not look complete, and will not work as expected
    my $self = shift;
    my $model = $self->model;
    my %args = @_;
    
    my @transcript_annotation_files = $self->_get_transcript_annotation_files();
    my $reports_dir = $self->build->resolve_reports_directory() . "/Pfam";
    unless(-d $reports_dir) 
    {
        mkdir($reports_dir);
    }

    #my $output_file = $self->report_detail_output_filename;
    my $output_buffer = "";
    #if(exists($args{report_detail}))
    #{
    #    $output_file = $args{report_detail};
    #}
    my ($snpdat_fh, $snpdat_file) =  File::Temp::tempfile(CLEANUP => 1, 
                                              DIR => $reports_dir );
    #print "producing: $output_file\n";
TRANSCRIPTFILE:    for my $transcript_file (@transcript_annotation_files) {
        print "processing $transcript_file\n";

        # make a file of only the annotation on coding transcripts
        my $coding_transcripts = 0;
        my $all_transcripts;
        my ($filtered_transcript_fh, 
            $filtered_transcript_file) = File::Temp::tempfile(CLEANUP => 1,
                                                              DIR => $reports_dir);
        my $transcript_fh = IO::File->new($transcript_file);
        #die "failed to open transcript file $transcript_file!: $!" unless $transcript_fh;
        unless($transcript_fh)
        {
            $self->error_message("failed to open transcript file $transcript_file!: $!");
            next TRANSCRIPTFILE;
        }
        while (my $line = $transcript_fh->getline) {
            if ($line =~ /nonsense|missense/) { # should silent be included?
                $filtered_transcript_fh->print($line);
                $coding_transcripts++;
            }
            $all_transcripts++;
        }
        $self->status_message("found $coding_transcripts coding transcripts out of $all_transcripts.");

        $self->_process_coding_transcript_file($filtered_transcript_file, $snpdat_file);        
    }
    $self->_run_report($snpdat_file, \$output_buffer);

    my $r = new CGI;
    my $body = IO::String->new();  
    die $! unless $body;
    $body->print( $r->start_html(-title=> 'Pfam report for ' . $model->genome_model_id ,));
    my $pfam_rpt = $self->format_report($output_buffer);
    $body->print("$pfam_rpt");
    $body->print( $r->end_html );
    #$body->close;
    
    $body->seek(0, 0);
    return join('', $body->getlines);

}

sub _process_coding_transcript_file {
    my $self = shift;
    my $coding_transcript_file = shift;

    my $iprscan_path = '/gscmnt/974/analysis/iprscan16.1/iprscan/bin';

    my $transcript_names_file = $coding_transcript_file . ".transcript_names";
    my $peptide_fasta_file = $coding_transcript_file . '.pep.fasta';
    my $iprscan_output = $coding_transcript_file . '.iprout';
    my $iprscan_gff = $coding_transcript_file . '.gff'; # does this need to be defined?
    my $snpdat_file = $coding_transcript_file . '.snps.dat';

    my $model = $self->model;
   
    # get the names of all of the transcripts in the input 
    print $coding_transcript_file,"\n";
    my @lines = read_file($coding_transcript_file);
    my @transcript_names;
    foreach my $line (@lines)
    {
        my @cols = split(/,/,$line);
        next unless defined($cols[11]);
        push(@transcript_names, $cols[11]."\n");
    }
    @transcript_names = uniq @transcript_names;
    write_file($transcript_names_file,@transcript_names);
 
    # determine which transcripts are new
    my @new_transcripts = $self->_call('mg-check-ts',$transcript_names_file);    
    $self->status_message("got " . scalar(@new_transcripts) . " new transcripts.");
    if($#new_transcripts > 0)
    {
        # make a fasta file of transcript sequences
        $self->_call(
            'mg-get-pep', 
            '--listfile', $transcript_names_file, 
            '--fasta', $peptide_fasta_file
        );
        $self->status_message("made peptide fasta file " . $peptide_fasta_file);
    
    # run interproscan. now in the _run_iprscan method
        $self->_run_iprscan( $peptide_fasta_file,$iprscan_gff);
#    $self->_call(
#        "$iprscan_path/iprscan.hacked",
#        '-cli',
#        '-i'            => $peptide_fasta_file, 
#        '-o'            => $iprscan_output,
#        '-iprlookup',
#        '-goterms',
#        '-appl'         => 'hmmpfam',
#        '-appl'         => 'superfamily',
#        '-format'       => 'raw'
#    );
#
#    # convert raw output to gff; maybe we could just specify gff3 above?
#    $self->_call(
#        "$iprscan_path/converter.pl",
#        '-input'  => $iprscan_output,
#        '-output' => $iprscan_gff,
#        '-format' => 'gff3',
#    );

    # load it up.
        unless($self->test_no_load())
        {
            $self->_call(
                "mg-load-ipro",
                "-gff" => $iprscan_gff,
            );
        } 
    }
    else
    {
        $self->status_message("no new transcripts to run, skipping interproscan,  and will run report.");
    }

    # this is in a method by itself now...
    $self->_create_snpsdat_file(\@lines,$snpdat_file);
    # need to create the snps.dat file, based on the 
#    my @snps_dat;
#    foreach my $line (@lines)
#    {
#        my @fields = split(/,/, $line);
#        my $snprecord = $fields[8]."\t".$fields[11].",".$fields[8]."\t".$fields[14]."\n";
#        push(@snps_dat,$snprecord);
#    }
#    # write that out to the tmp snp file
#    write_file($snpdat_file,@snps_dat);

    return 1;    
}

=head2 _run_iprscan

separate out the running of interproscan

=cut

sub _run_iprscan
{
    my ($self,$peptide_fasta_file,$iprgff) = @_;
    my $reports_dir = $self->build->resolve_reports_directory() . "/Pfam";
    my $iprscan_path = '/gscmnt/974/analysis/iprscan16.1/iprscan/bin';
    my ($fh, $iprscan_output) = File::Temp::tempfile(CLEANUP => 1,
                                                     DIR => $self->_reports_dir(),
                                                     DIR => $reports_dir,
                                                     SUFFIX => '.raw');
    # run interproscan
    $self->_call(
        "$iprscan_path/iprscan.hacked",
        '-cli',
        '-i'            => $peptide_fasta_file, 
        '-o'            => $iprscan_output,
        '-iprlookup',
        '-goterms',
        '-appl'         => 'hmmpfam',
        '-appl'         => 'superfamily',
        '-format'       => 'raw'
    );

    # convert raw output to gff; maybe we could just specify gff3 above?
    $self->_call(
        "$iprscan_path/converter.pl",
        '-input'  => $iprscan_output,
        '-output' => $iprgff,
        '-format' => 'gff3',
    );

    return 1;
}


=head2 _create_snpsdat_file

the creation of the snpsdat file separated out

=cut

sub _create_snpsdat_file
{
    my ($self,$lines,$snpdat_file) = @_;

    my @snps_dat;
    foreach my $line (@$lines)
    {
        my @fields = split(/,/, $line);
        next unless($#fields > -1);
        my $snprecord = $fields[8]."\t".$fields[11].",".$fields[8]."\t".$fields[14]."\n";
        push(@snps_dat,$snprecord);
    }
    # write that out to the tmp snp file
    unless(write_file($snpdat_file, {err_mode => 'carp'}, @snps_dat))
    {
        $self->error_message("problem writing out to $snpdat_file");
        return 0;
    }

    return 1;
}


sub _run_report 
{
    my ($self,$tmpsnp_file) = @_;
    my $reports_dir = $self->build->resolve_reports_directory() . "/Pfam";
    my ($report_fh, $report_file) = File::Temp::tempfile(DIR => $reports_dir,
                                                         CLEANUP => 1,
                                                         SUFFIX => 'pfam.csv',);
    my $report_buffer;
    # run report generation.
    $self->_call(
        "mg-ipr-families",
        "--snps" => $tmpsnp_file,
        "--coords" => "1,2",
        "--output" => $report_file,
#        "--filter" => "\"(HMMPfam)\"", # do we want to create the report on everything or just HMMPfam
    );

    $report_buffer = read_file($report_file);

    return $report_buffer;
}

sub format_report
{
    #assumes plain-text
    #convert newlines to divs, and tabs to padded spans
    my ($self, $content) = @_;
    my $model = $self->model;
    my $result = "\n<!--\n$content\n-->\n";    
    $content = "<pre>\n".$content."</pre>\n";
#    if ($content=~m/(\s*)(.*)(\s*)/sm)
#    {
#        $content = $2;
#        my $span = "<span style=\"padding-left:10px;\">";#

#        $content=~s/\n/<\/div>\n<div>/g;
#        $content=~s/(<div>)(\t)(.*)(<\/div>)/$1\n$span$3<\/span>\n$4/g;
#        $content=~s/\t/<\/span>$span/g;
#        $content=~s/(.*<\/div>\s*)(<div>\s*There were .+)/$1<\/p>\n<hr align=\"left\">\n<p>$2/g;
#        $content = "<h1>Gold Concordance for " . $model->genome_model_id . "</h1>\n\n" .
#                   "<p><div>$content</div><p>" .
#                   $self->get_css;
        return $content;
#    }
}

sub get_css
{
    return 
"<style>
    p {font-size:16px;background-color:tan;}
    span {font-size:.9em}
    hr {width:30%;} 
</style>";

}

sub _get_transcript_annotation_files {
    my $self = shift;
    my $model = $self->model;

    my $build = $model->current_running_build;
    unless (defined $build) {
        $build = $model->last_complete_build;
    }
    unless (defined $build) {
        die "No builds are available to retrieve transcript annotation files";
    }

    my @files = $build->_transcript_annotation_files;
    #my @files = $last_complete_build->_transcript_annotation_files(22);
    return @files;
}


1;
