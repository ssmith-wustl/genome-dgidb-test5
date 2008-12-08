package Genome::Model::Tools::Maq::AlignReads;

use strict;
use warnings;

use Genome;
use Genome::Utility::FileSystem; 

class Genome::Model::Tools::Maq::AlignReads {
    is => 'Command',
    has => [
           #######################################################		
           dna_type => {
			 doc => 'Optional switch which can be "dna" or "rna".  Each choice causes the application to use a specific primer file.  If no dna_type value is provided, an adaptor_file parameter must be used.',
		         is => 'String',
			 is_optional => 1,
           }
           ,
	   adaptor_file => {
			doc => 'Optional input file containing the appropriate pcr primer or adaptor strings.',
 			is => 'String',
			is_optional => 1,
	   }  
	   ,
	   align_options => {
			doc => 'The maq align reads parameters. These should be specified in a quoted string with single dashes, e.g. "-x -y -z"',
		        is => 'String',
			is_optional => 1,
                        default_value => '',
	   }
	   ,

	   upper_bound => {
			doc => 'The maq option (-a) designating the upper bound on insert size. Defaults to 600.',
		        is => 'Integer',
			is_optional => 1,
			default_value => 600,
	   }
	   ,

	   execute_sol2sanger => {
			doc => 'An option to execute a sol2sanger conversion on the input fastq files.  "y"=yes, "n"=no.  Defaults to "no".',
		        is => 'String',
			is_optional => 1,
			default_value => 'n',
	   }
	   ,

	   maq_version => {
			doc => 'An option containing the maq version to use.',
		        is => 'String',
			is_optional => 1,
			default_value => 'maq-0.6.8_x86_64-linux',
	   }
	   ,
	   maq_path => {
			doc => 'Optional parameter containing full maq tool path.',
		        is => 'String',
			is_optional => 1,
                        #default_value = '/gsc/pkg/bio/maq/maq-0.6.8_x86_64-linux/maq',
           }
	   ,

	   #####################################################
           #input files

	   ref_seq_file => {
			doc => 'Optional input file name containing the reference sequence file.  If no file is provided, will default to "all_sequences.bfa"',           
	  		is => 'String',
			default_value => 'all_sequences.bfa',
			is_optional => 1,
			#this may be optional, might require a seq id and some processing 
           }
	   , 
	   files_to_align_path => {
			doc => 'Path (directory or file) containing input files to be aligned.  May be in fastq or bfq format.',
			is => 'String',
	   }
	   ,

	   #####################################################
	   #output files

	   aligner_output_file => {
			doc => 'Optional output file containing results of the run.  If no file is specified, the output will be directed to the screen.',
			is => 'String',
			is_optional => 1,
			#this may be optional
	   }
	   ,    
	   alignment_file => {
			doc => 'Optional output file containing the aligned map data.  If no file is provided, will default to "all.map"',
			is => 'String',
			is_optional => 1,
			default_value => 'all.map',
	   }
           ,
	   unaligned_reads_file => {
			doc => 'Output file containing unaligned data.',
		        is => 'String',
           }
	   ,
	   output_directory => {
			doc => 'Optional output directory.  All output files will be placed here.',
			is => 'String',
			is_optional => 1,
                        default_value => 'output',
	   }
	   ,
	   temp_directory => {
			doc => 'Optional temp directory where fastq and bfqs will be stored if generated.  If no temp directory is specified, a temporary directory in /tmp will be created and then removed.',
			is => 'String',
			is_optional => 1,
                        #default_value => 'tmp',
	   }
	   ,
           #####################################################
           #private variables
           _files_to_align_list => {
			 doc => 'The list of input files to align.',
			 is => 'List',
			 is_optional => 1,
	   }
           ,
        ],
};

sub prepare_input {

}


sub help_brief {
    'a tool for aligning reads (todo update this) ';
}

sub help_detail {
    return <<"EOS"
help detail for align reads todo: update
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
 
    #switch based on version
    unless ( defined($self->maq_path) ) {
	$self->maq_path('/gsc/pkg/bio/maq/'.$self->maq_version.'/maq');
    }   
    $self->status_message("Using aligner tool: ".$self->maq_path);
    #default maq_path is '/gsc/pkg/bio/maq/maq-0.6.8_x86_64-linux/maq';

    my $output_dir;
    unless (-d $self->output_directory) {
    	$output_dir =  Genome::Utility::FileSystem->create_directory($self->output_directory);
    }

    
    $self->alignment_file($self->output_directory.'/'.$self->alignment_file); 
    $self->unaligned_reads_file($self->output_directory.'/'.$self->unaligned_reads_file); 
    $self->aligner_output_file($self->output_directory.'/'.$self->aligner_output_file); 
 
    #these are constants and should probably be defined in class properties...todo
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
     #check to see if files to align path is a dir or file
     if (-f $self->files_to_align_path) {
	#$self->status_message('Path is a file');
        push @listing, $self->files_to_align_path;
     } elsif (-d $self->files_to_align_path) {
	#$self->status_message('Path is dir.');
        @listing = glob($self->files_to_align_path.'/*');
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
           $self->error_message('Could not determine the input file type.');
           #todo...Please specify on the command line with the "--input-file-type=bfq" option for bfq.');  
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
        #todo: $self->error_message('To bypass file type detection, please specify the "--input-file-type=bfq" option for bfq.');  
        return;
     } 

     #if the input files are fastq (ascii) convert them using sol2sanger
     if ( $ascii_count > 0 ) {
        my $tmp_dir;
        if ( defined($self->temp_directory) ) {
     		$tmp_dir =  Genome::Utility::FileSystem->create_directory($self->temp_directory);
        } else {
	        $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
        }
     	#$self->status_message("temp dir:".$tmp_dir);

     	my @bfq_pathnames;
     	my $counter=0;
     	for my $solexa_output_path (@listing) {
		
		my $fastq_pathname;
                if ( $self->execute_sol2sanger eq lc('y') ) {
		        $fastq_pathname = "$tmp_dir/fastq-$counter";
                	my $sol_cmd = $self->maq_path." sol2sanger $solexa_output_path $fastq_pathname";
			$self->status_message('sol2sanger cmd:'.$sol_cmd);

     	        	Genome::Utility::FileSystem->shellcmd(
                   		cmd => $sol_cmd,
                  		input_files => [$solexa_output_path],
                 		output_files => [$fastq_pathname],
                 		skip_if_output_is_present => 1,
            		);
 		} else {
		  	$fastq_pathname = $solexa_output_path;
			$self->status_message('No sol2sanger conversion is being performed.');
		}
            	
		my $bfq_pathname = "$tmp_dir/bfq-$counter";
        	my $bfq_cmd = $self->maq_path." fastq2bfq  $fastq_pathname $bfq_pathname";
		$self->status_message('fastq2bfq cmd:'.$bfq_cmd);

     	        Genome::Utility::FileSystem->shellcmd(
                   cmd => $bfq_cmd,
                   input_files => [$fastq_pathname],
                   output_files => [$bfq_pathname],
                   skip_if_output_is_present => 1,
                );

		$counter++;
                push @bfq_pathnames, $bfq_pathname; 
    	} 

	$self->_files_to_align_list(@bfq_pathnames); 		

     #end sol2sanger conversion if-block	
     } elsif ( $binary_count > 0 ) { 
        #files are already binary, use those
        $self->status_message("Using bfqs.");
     	$self->_files_to_align_list(@listing);
     }  

    return $self;
}

sub create_temp_file {

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
    $self -> status_message('Files to align list:'.$self->_files_to_align_list);
    $self -> status_message('');
    $self -> status_message('Output Files:');
    $self -> status_message('Alignment file:'.$self->alignment_file);
    $self -> status_message('Unaligned reads file:'.$self->unaligned_reads_file);
    $self -> status_message('Aligner output messages:'.$self->aligner_output_file);
    $self -> status_message('');
    $self -> status_message('Other Parameters:');
    $self -> status_message('DNA type:'.$self->dna_type) if defined($self->dna_type);
    $self -> status_message('Adaptor file:'.$self->adaptor_file) if defined($self->adaptor_file);
    $self -> status_message('Align options:'.$self->align_options) if defined($self->align_options);
    $self -> status_message('Upper bound value:'.$self->upper_bound) if defined($self->upper_bound);
    $self -> status_message('Sol2sanger flag:'.$self->execute_sol2sanger) if defined($self->execute_sol2sanger);
    $self -> status_message('Maq version:'.$self->maq_version) if defined($self->maq_version);
    $self -> status_message("\n");

    
    #maq path stuff, does this need to support previous versions? See: /dev/trunk/Genome/Model/Command/MaqSubclasser.pm
    #my $aligner_path = '/gsc/pkg/bio/maq/maq-0.6.8_x86_64-linux/maq';

    #get the files to align ready   
    my @tmp_list = $self->_files_to_align_list;
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

    my $aligner_params = join(' ', $self->align_options, $upper_bound_option, $aligner_adaptor_option);


#$self->output_directory.'/'.$self->alignment_file,

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

       #output_files                => [$self->output_directory.'/'.$self->alignment_file, $self->unaligned_reads_file, $self->aligner_output_file],
   
   # run the aligner
   Genome::Utility::FileSystem->shellcmd(
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
