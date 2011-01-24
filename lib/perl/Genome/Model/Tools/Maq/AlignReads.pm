package Genome::Model::Tools::Maq::AlignReads;

use strict;
use warnings;

use Genome;
use Genome::Sys;

class Genome::Model::Tools::Maq::AlignReads {
    is => 'Genome::Model::Tools::Maq',
    has => [
           #######################################################
            use_version => {
                            is => 'Version',
                            default_value => '0.7.1',
                            doc => "Version of maq to use"
                        },
           dna_type => {
			 doc => 'Optional switch which can be "dna" or "rna".  Each choice causes the application to use a specific primer file.  If no dna_type value is provided, an adaptor_file parameter must be used.',
		         is => 'String',
			 is_optional => 1,
           },
	   adaptor_file => {
			doc => 'Optional input file containing the appropriate pcr primer or adaptor strings.',
 			is => 'String',
			is_optional => 1,
	   },
	   align_options => {
			doc => 'The maq align reads parameters. These should be specified in a quoted string with single dashes, e.g. "-x -y -z"',
		        is => 'String',
			is_optional => 1,
                        default_value => '',
	   },
	   upper_bound => {
			doc => 'The maq option (-a) designating the upper bound on insert size. Defaults to 600.',
		        is => 'Integer',
			is_optional => 1,
			default_value => 600,
	   },
           quality_converter => {
                              is => 'String',
                              is_optional => 1,
                              doc => 'The algorithm to use for converting fastq quality scores, sol2sanger(old) or sol2phred(new)',
                          },
	   force_fragments => {
		doc => 'Optional switch to force fragment processing.',
	        is => 'Integer',
		is_optional => 1,
		default_value => 0,
           },
	   #####################################################
           #input files
	   ref_seq_file => {
			doc => 'Required input file name containing the reference sequence file.',           
	  		is => 'String',
           },
	   files_to_align_path => {
			doc => 'Path to a directory or a file or a pipe separated list of files containing the reads to be aligned.  May be in fastq or bfq format.',
			is => 'String',
	   },
	   #####################################################
	   #output files
	   aligner_output_file => {
			doc => 'Optional output log file containing results of the run.',
			is => 'String',
	   },
	   alignment_file => {
			doc => 'Optional output file containing the aligned map data.',
			is => 'String',
	   },
	   unaligned_reads_file => {
			doc => 'Output file containing unaligned data.',
		        is => 'String',
           },
	   duplicate_mismatch_file => {
			doc => 'Output file containing dumped duplicate mismatches specified by the (-H) maq parameter. There is no default value.  If this file is not specified duplicate mismatches will not be dumped',
		        is => 'String',
                        is_optional => 1,
           },
	   temp_directory => {
			doc => 'Optional temp directory where fastq and bfqs will be stored when generated.  If no temp directory is specified, a temporary directory in /tmp will be created and then removed.',
			is => 'String',
			is_optional => 1,
	   },
           #####################################################
           #private variables
           _files_to_align_list => {
			 doc => 'The list of input files to align.',
			 is => 'List',
			 is_optional => 1,
	   },
        ],
};

sub help_synopsis {
return <<EOS
    A Maq based utility for aligning reads using the "map" command.;
EOS
}

sub help_brief {
    return <<EOS
    A Maq based utility for aligning reads using the "map" command.;
EOS
}

sub help_detail {
    return <<EOS
Provides an interface to the Maq "map" command.  Inputs are:

'ref-seq-file' - The reference sequence file which to align reads to.  Specified by a path to a file. 

'files-to-align-path' - The file or set of files which contain the read fragments which are going to be aligned to the reference sequence.  The path can be a single file, a pipe seperated list of two files for paired end reads, or a directory containing one or two files.  These files can be in the fasta format or bfq format.  The application will attempt to detect which type of files are being used.    


EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_); 

    unless ($self) {
        return;
    }

    unless ($self->use_version) {
        my $msg = 'use_version is a required parameter to '. $class;
        $self->delete;
        die($msg);
    }
    unless ($self->maq_path) {
        my $msg = 'No path found for maq version '. $self->use_version .".  Available versions are:\n";
        $msg .= join("\n", $self->available_maq_versions);
        $self->delete;
        die($msg);
    }
    
    #these are constants and should probably be defined in class properties...TODO
    my $dna_primer_file = '/gscmnt/sata114/info/medseq/adaptor_sequences/solexa_adaptor_pcr_primer';
    my $rna_primer_file = '/gscmnt/sata114/info/medseq/adaptor_sequences/solexa_adaptor_pcr_primer_SMART';

    unless( defined($self->adaptor_file) ) {
       #adaptor file is not defined.  use the dna_type parameter to select the adaptor file 
       if ( defined($self->dna_type) ) 
       {
     		if ( $self->dna_type eq 'dna' ) {
		  	$self->adaptor_file($dna_primer_file);
		} elsif ( $self->dna_type eq 'rna' ) {
		  	$self->adaptor_file($rna_primer_file);
		} else {
                      $self->error_message("dna-type parameter must be 'dna' or 'rna'.  If you do not want to use an adopter file, leave this parameter blank.");
		      return; 	 
                }
       } 
    } #end unless 

     #if the adaptor file has been defined, make sure it exists
     if ( defined($self->adaptor_file) ) {
     	unless(-f $self->adaptor_file) {
       	         $self->error_message('Specified adaptor file'.$self->adaptor_file.' does not exist.');
       	         return;
     	}
     }

     my @listing;
     my $dir_flag=0;
     my @pipe_list;

     #check to see if files to align path is a pipe delimited list of files
     $self->status_message("Files to align: ".$self->files_to_align_path);
     my $pipe_char_index = index($self->files_to_align_path,'|');
     #$self->status_message("Comma index: ".$pipe_char);
     if ($pipe_char_index > -1) {
	@pipe_list = split(/\|/,$self->files_to_align_path);
	for my $pipe_file (@pipe_list) {
	        #make sure each file exists
		if (-f $pipe_file) {
			push @listing, $pipe_file;
		} else {
           		$self->error_message('File does not exist: '.$pipe_file);
		}
	}
     } else {
        #not a pipe delimited list	
	#check to see if files to align path is a dir or file
     	if (-f $self->files_to_align_path) {
		#$self->status_message('Path is a file');
       		 push @listing, $self->files_to_align_path;
     	} elsif (-d $self->files_to_align_path) {
		#$self->status_message('Path is dir.');
       		 @listing = glob($self->files_to_align_path.'/*');
     	} else {
           	$self->error_message('Input file does not exist.');
	}
     } 

     my $binary_count = 0;
     my $ascii_count = 0;
     for my $file (@listing) {
     	#$self->status_message('file: '.$file);
        if (-T $file) {
	   #$self->status_message('File is ascii.');
           $ascii_count++; 
        } elsif (-B $file) {
           #$self->status_message('File is binary.');
           $binary_count++;
        } else {
	   $self->error_message('Could not determine the input file type or file may not exist.');
           #TODO...Please specify on the command line with the "--input-file-type=bfq" option for bfq.');  
        }
     } #end for $file loop


     #check for some number of files greater than 0- else return 
     if (@listing eq 0) {
        $self->error_message('No files have been found to process.');
        return;
     } 
     
     #if you have a mix of binary and ascii input, assume there is a problem.
     if ( $binary_count > 0  && $ascii_count > 0 ) {
	$self->error_message("Binary AND ascii file types have been detected.  Only one type of file is allowed.");
        #TODO: $self->error_message('To bypass file type detection, please specify the "--input-file-type=bfq" option for bfq.');  
        return;
     } 



     #if the input files are fastq (ascii) execute quality conversion if desired, then always fastq to bfq
     if ( $ascii_count > 0 ) {
        my $tmp_dir;
        if ( defined($self->temp_directory) ) {
     		$tmp_dir =  Genome::Sys->create_directory($self->temp_directory);
        } else {
	        $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
        }
     	#$self->status_message("temp dir:".$tmp_dir);

     	#if the 'force_fragments' flag is set AND there are paired end reads, cat them together.  Replace the entry in @listing with the new file.
        my $force_frag_file;	
        #my @combined_flie;
	if ($ascii_count > 1 && $self->force_fragments) {
     	        $self->status_message("Forcing fragments.");
        	$force_frag_file = "$tmp_dir/force-frag";
     	        $self->status_message("Frag file: ".$force_frag_file);
                my $cmd = "cat ".join(" ",@listing)." > ".$force_frag_file;
     	        $self->status_message("Cat command: ".$cmd);
                my @result = `$cmd`;
                #clear the listing and replace it with the new combined file name for processing
                @listing = ();
                push (@listing, $force_frag_file );
     	        $self->status_message("Listing contains: ".join(" ",@listing) );
        }

        #start processing the files 
     	my @bfq_pathnames;
     	my $counter=0;
     	for my $solexa_output_path (@listing) {
		my $fastq_pathname;
                if ( $self->quality_converter ) {
		        $fastq_pathname = "$tmp_dir/fastq-$counter";
                	my $quality_converter_cmd;
                        if ($self->quality_converter eq 'sol2sanger') {
                            $quality_converter_cmd = $self->maq_path ." sol2sanger $solexa_output_path $fastq_pathname";
                        } elsif ($self->quality_converter eq 'sol2phred') {
                            $quality_converter_cmd = "gmt fastq sol2phred --fastq-file=$solexa_output_path --phred-fastq-file=$fastq_pathname";
                        }
			$self->status_message('quality converter cmd:'. $quality_converter_cmd);

     	        	Genome::Sys->shellcmd(
                   		cmd => $quality_converter_cmd,
                  		input_files => [$solexa_output_path],
                 		output_files => [$fastq_pathname],
                 		skip_if_output_is_present => 1,
            		);
 		} else {
		  	$fastq_pathname = $solexa_output_path;
			$self->status_message('No quality conversion is being performed.');
		}
		my $bfq_pathname = "$tmp_dir/bfq-$counter";
        	my $bfq_cmd = $self->maq_path ." fastq2bfq  $fastq_pathname $bfq_pathname";
		$self->status_message('fastq2bfq cmd:'.$bfq_cmd);

     	        Genome::Sys->shellcmd(
                   cmd => $bfq_cmd,
                   input_files => [$fastq_pathname],
                   output_files => [$bfq_pathname],
                   skip_if_output_is_present => 1,
                );

		$counter++;
                push @bfq_pathnames, $bfq_pathname;
    	}

	$self->_files_to_align_list(\@bfq_pathnames);

     #end sol2sanger conversion if-block
     } elsif ( $binary_count > 0 ) {
        #files are already binary, use those
        $self->status_message("Using bfqs.");
     	$self->_files_to_align_list(\@listing);
     }

    return $self;
}

sub _check_maq_successful_completion {
    my($self,$output_filename) = @_;

    my $aligner_output_fh = IO::File->new($output_filename);
    unless ($aligner_output_fh) {
        $self->error_message("Can't open aligner output file $output_filename: $!");
        return;
    }

    while(<$aligner_output_fh>) {
        if (m/match_data2mapping/) {
            $aligner_output_fh->close();
            return 1;
        }
    }

    $self->status_message("Alignment shortcut failure.  No line found matching /match_data2mapping/ in the maq output file '$output_filename'");
     return;
}

sub execute {
    my $self = shift;

    $self -> status_message("\n");
    $self -> status_message('Running AlignReads with parameters');
    $self -> status_message('-----------------------------------');
    $self -> status_message('Input Files:');
    $self -> status_message('Reference sequence file:'.$self->ref_seq_file);
    $self -> status_message('Files to align path:'.$self->files_to_align_path);
    $self -> status_message('Files to align list:'. $self->_files_to_align_list);
    $self -> status_message('');
    $self -> status_message('Output Files:');
    $self -> status_message('Alignment file:'.$self->alignment_file);
    $self -> status_message('Unaligned reads file:'.$self->unaligned_reads_file) if defined($self->unaligned_reads_file);
    $self -> status_message('Aligner output messages:'.$self->aligner_output_file) if defined($self->aligner_output_file);
    $self -> status_message('');
    $self -> status_message('Other Parameters:');
    $self -> status_message('DNA type:'.$self->dna_type) if defined($self->dna_type);
    $self -> status_message('Adaptor file:'.$self->adaptor_file) if defined($self->adaptor_file);
    $self -> status_message('Align options:'.$self->align_options) if defined($self->align_options);
    $self -> status_message('Upper bound value:'.$self->upper_bound) if defined($self->upper_bound);
    $self -> status_message('Quality conversion:'.$self->quality_converter) if defined($self->quality_converter);
    $self -> status_message('Maq version:'. $self->use_version) if defined($self->use_version);
    $self -> status_message("\n");

    
    #maq path stuff, does this need to support previous versions? See: /dev/trunk/Genome/Model/Command/MaqSubclasser.pm
    #my $aligner_path = '/gsc/pkg/bio/maq/maq-0.6.8_x86_64-linux/maq';

    #get the files to align ready   
    my @tmp_list = @{$self->_files_to_align_list};
    my $files_to_align = join(' ',@tmp_list); 
    
    #insert the primer or adaptor file if it is specified  
    my $aligner_adaptor_option = "";
    if ( defined($self->adaptor_file) ) {
       $aligner_adaptor_option = '-d '.$self->adaptor_file;
    }
    
    my $upper_bound_option = "";
    if ( @tmp_list > 1 ) {
   	$upper_bound_option = '-a '.$self->upper_bound;
    }   

    my $duplicate_mismatch_option = "";
    if ( defined($self->duplicate_mismatch_file) ) {
       $duplicate_mismatch_option = '-H '.$self->duplicate_mismatch_file;
    }

    my $aligner_params = join(' ', $self->align_options, $upper_bound_option, $aligner_adaptor_option, $duplicate_mismatch_option);

    my $cmdline =
        $self->maq_path
        . sprintf(' map %s -u %s %s %s %s > ',
                          $aligner_params,
                          $self->unaligned_reads_file,
                          $self->alignment_file,
                          $self->ref_seq_file,
                          $files_to_align)
        . $self->aligner_output_file
        . ' 2>&1';

    $self -> status_message($cmdline);

   # run the aligner
   Genome::Sys->shellcmd(
       cmd                         => $cmdline,
       input_files                 => [$self->ref_seq_file, @tmp_list],
       output_files                => [$self->alignment_file, $self->unaligned_reads_file, $self->aligner_output_file],
       skip_if_output_is_present   => 1,
   );
   unless ($self->_check_maq_successful_completion($self->aligner_output_file))
   {
     return;
   }
   return 1;
}


1;
