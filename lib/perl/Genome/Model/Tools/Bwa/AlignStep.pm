package Genome::Model::Tools::Bwa::AlignStep;

use strict;
use warnings;

use Genome;

use File::Basename;
use IO::File;
use Sys::Hostname;


class Genome::Model::Tools::Bwa::AlignStep{
    is => ['Command'],
    has_input => [
    aligner_version => {
	is => 'String',
	doc => 'Aligner version'
    },
    alignments_dir => {
        is => 'String',
        doc => 'Alignments directory.' 
    },
    query_input => {
        is => 'String',
        doc => 'Query input fastq',
    },
    reference_fasta_path => {
        is => 'String',
        doc => 'Reference fasta path',
    },
    bwa_aln_params => {
	is => 'String',
	doc=> 'Params to bwa aln',	
    },
    output_path => {
	is => 'String',
	doc => 'Path to an output path for the .sai files - use alignments_dir if not specified',
	is_optional => 1
    }
    ],
    has_param => [
        lsf_resource => {
            default_value => 'select[model!=Opteron250 && type==LINUX64] rusage[mem=2000]',
        }
    ],


    has_output => [
	fastq_file => {
	    is => 'String',
	    is_optional => 1
	},
	sai_file => {
	    is => 'String',
	    is_optional => 1
	},
	output_file => { 
	    is => 'String',
	    is_optional => 1
	},
    ],
};

sub execute {
    my $self=shift;

    my $pid = getppid();
    my $hostname = hostname;
    my $log_dir = $self->alignments_dir.'/logs/';
    unless (-e $log_dir ) {
	unless( Genome::Sys->create_directory($log_dir) ) {
            $self->error_message("Failed to create log directory for align process: $log_dir");
            return;
	}
    }
    
    $self->fastq_file($self->query_input);
   
   
   
  my $log_file = $log_dir.'/parallel_bwa_aln_'.$pid.'.log';
    my $log_fh = Genome::Sys->open_file_for_writing($log_file);
    unless($log_fh) {
       $self->error_message("Failed to open output filehandle for: " .  $log_file );
       die "Could not open file ".$log_file." for writing.";
    } 

    my $now = UR::Time->now;
    print $log_fh "Executing AlignStep.pm at $now on $hostname\n";

   my $q_basename = basename($self->query_input);
   my $sai_file = sprintf("%s/%s.sai", ($self->output_path ? $self->output_path : $self->alignments_dir), $q_basename);
   my $output_file = sprintf("%s/%s.log", ($self->output_path ? $self->output_path : $self->alignments_dir ."/logs/"), $q_basename);

    my $cmdline = Genome::Model::Tools::Bwa->path_for_bwa_version($self->aligner_version)
        . sprintf( ' aln %s %s %s 1> ',
		       $self->bwa_aln_params, $self->reference_fasta_path, $self->query_input )
	    . $sai_file . ' 2>>'
	    . $output_file;
		
        # run the aligner
    print $log_fh "bwa aln cmd line is $cmdline.\n";
    Genome::Sys->shellcmd(
         cmd          => $cmdline,
        input_files  => [ $self->reference_fasta_path, $self->query_input ],
        output_files => [ $sai_file, $output_file ],
        skip_if_output_is_present => 0,
        );
    unless ($self->_verify_bwa_aln_did_happen(sai_file => $sai_file,
    					  log_file => $output_file)) {
        print $log_fh ("ERROR: bwa aln did not seem to successfully take place for " . $self->reference_fasta_path . "\n----\n" . $self->error_mesasge . "\n");
        return;
    }
  
   $self->sai_file($sai_file);
   $self->output_file($output_file);
  
   $now = UR::Time->now;
   print $log_fh "<<< Completed bwa aln at $now .\n";

   $log_fh->close;
   return 1;
} #end execute

sub _verify_bwa_aln_did_happen {
    my $self = shift;
    my %p = @_;

    unless (-e $p{sai_file} && -s $p{sai_file}) {
	$self->error_message("Expected SAI file is $p{sai_file} nonexistent or zero length.");
	return;
    }
    
    unless ($self->_inspect_log_file(log_file=>$p{log_file},
				     log_regex=>'(\d+) sequences have been processed')) {
	
	$self->error_message("Expected to see 'X sequences have been processed' in the log file where 'X' must be a nonzero number.");
	return 0;
    }
    
    return 1;
}

sub _inspect_log_file {
    my $self = shift;
    my %p = @_;

    my $aligner_output_fh = IO::File->new($p{log_file});
    unless ($aligner_output_fh) {
        $self->error_message("Can't open expected log file to verify completion " . $p{log_file} . "$!"
        );
        return;
    }
    
    my $check_nonzero = 0;
    
    my $log_regex = $p{log_regex};
    if ($log_regex =~ m/\(\\d\+\)/) {
	
	$check_nonzero = 1;
    }

    while (<$aligner_output_fh>) {
        if (m/$log_regex/) {
            $aligner_output_fh->close();
            if ( !$check_nonzero || $1 > 0 ) {
                return 1;
            }
            return;
        }
    }

    return;
}


1;
