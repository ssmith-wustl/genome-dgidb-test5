package Genome::Model::Command::Build::ReferenceAlignment::DeduplicateLibraries::Dedup;

use strict;
use warnings;

use Genome;
use Command;
use File::Basename;
use IO::File;

class Genome::Model::Command::Build::ReferenceAlignment::DeduplicateLibraries::Dedup {
    is => ['Genome::Model::Command::MaqSubclasser'],
    has_input => [
    accumulated_alignments_dir => {
        is => 'String',
        doc => 'Accumulated alignments directory.' 
    },
    library_alignments => {
        is => 'String',
        doc => 'Hash of library names and related alignment files.' 
    },
    subreference_names => {
        is => 'ARRAY',
        doc => 'List of subreference names: 1..22,X,Y,all_sequences'
    },
    aligner_version => {
                        is => 'Text',
                        doc => 'The maq read aligner version used',
                    },
    ],
    has_param => [
        lsf_resource => {
            default_value => 'select[model!=Opteron250 && type==LINUX64] rusage[mem=2000]',
        }
    ],


    has_output => [
    output_file => { 
        is => 'String', 
        is_optional => 1, 
    }
    ],
};


sub make_real_rmdupped_map_file {
    my $self=shift;
    my $maplist=shift;
    my $library=shift;

    $self->status_message("Library: ".$library." Maplist: ".$maplist);

    my $final_file = $self->accumulated_alignments_dir .  "/" .  $library.".map";
    $self->status_message("Final file: ". $final_file );

    if (-s "$final_file") {
        $self->status_message("Rmdup'd file exists: ".$final_file);
    } else {
        my $tmp_file = Genome::Utility::FileSystem->create_temp_file_path($library.".map" );
        $self->status_message("Rmdup'd file DOES NOT exist: ".$final_file);
        my $aligner_version = $self->aligner_version;
        my $maq_cmd = "gt maq vmerge --version=$aligner_version --maplist $maplist --pipe $tmp_file &";
        $self->status_message("Executing:  $maq_cmd");
        system "$maq_cmd";
        my $start_time = time;
        until (-p "$tmp_file" or ( (time - $start_time) > 100) )  {
            sleep(5);
        }
        unless (-p "$tmp_file") {
            die "failed to make intemediate file for (library) maps $!";
        }
        $self->status_message("Streaming into file $tmp_file.");
        unless (-p "$tmp_file") {
            die "Failed to make intermediate file for (library) maps $!";
        }

        ##TODO: where should i be getting this.
        my $maq_pathname = Genome::Model::Tools::Maq->path_for_maq_version($self->aligner_version);
        my $cmd = $maq_pathname . " rmdup " . $final_file . " " . $tmp_file;
        $self->status_message("running $cmd");
        my $rv = system($cmd);
        if($rv) {
            $self->error_message("problem with maq rmdup: $!");
            return;
        }
    }	
    return $final_file;
}

sub status_message {
    my $self=shift;
    my $msg=shift;
    print $msg . "\n";
}

sub execute {
    my $self=shift;
    #my $maplist=shift;
    #my $library=shift;

    my $pid = getppid(); 
    my $log_dir = $self->accumulated_alignments_dir.'/../logs/';
    unless (-e $log_dir ) {
	unless( Genome::Utility::FileSystem->create_directory($log_dir) ) {
            $self->error_message("Failed to create log directory for dedup process: $log_dir");
            return;
	}
    } 
    my $log_file = $log_dir.'/parallel_dedup_'.$pid.'.log';
    #my $log_file = '/parallel_dedup_'.$pid.'.log';
    #my $log_file = '/gscmnt/sata363/info/medseq/parallel_dedup_'.$pid.'.log';
    #print("\nLog file: ".$log_file."\n");
    open(STDOUT, ">$log_file") || die "Can't redirect stdout.";
    open(STDERR, ">&STDOUT"); 

    my $now = UR::Time->now;
    $self->status_message("Executing Dedup.pm at $now");

    #$self->status_message($log, "Library alignments is a: ".ref($self->library_alignments));
    my @list;
    if ( ref($self->library_alignments) ne 'ARRAY' ) {
        push @list, $self->library_alignments; 		
    } else {
        @list = @{$self->library_alignments};   	#the parallelized code will only receive a list of one item. 
    }

    $self->status_message("Input library list length: ".scalar(@list));
    for my $list_item ( @list  ) {
        my %hash = %{$list_item};    		#there will only be one name-value-pair in the hash: $library name -> @list of alignment file paths (maps)
        for my $library ( keys %hash  ) {
            my @library_maps = @{$hash{$library}};
            #print "\nkey:>$library<  /  value:>".join(",",@library_maps)."<";
            $self->status_message("key:>$library<  /  value:>".scalar(@library_maps)."<");

            my $library_maplist = $self->accumulated_alignments_dir .'/' . $library . '.maplist';
            $self->status_message("Library Maplist File:" .$library_maplist);
            my $fh = IO::File->new($library_maplist,'w');
            unless ($fh) {
                $self->error_message("Failed to create filehandle for '$library_maplist':  $!");
                return;
            }
            my $cnt=0;
            for my $input_alignment (@library_maps) {
                unless(-f $input_alignment) {
                    $self->error_message("Expected $input_alignment not found");
                    return;
                }
                $cnt++;
                print $fh $input_alignment ."\n";
            }
            $self->status_message("Library $library has $cnt map files");
            $fh->close;

            $now = UR::Time->now;
            $self->status_message(">>> Starting make_real_rmdupped_map_file() at $now for library: $library .");
            my $map_file =  $self->make_real_rmdupped_map_file($library_maplist, $library);
            $now = UR::Time->now;
            $self->status_message("<<< Completed make_real_rmdupped_map_file() at $now for library: $library .");

            unless($map_file) {
                $self->error_message("Something went wrong with 'make_real_rmdupped_map_file'");
                return;
            }

                ###############
		#Beginning Map-2-Bam conversion

		$now = UR::Time->now;
		$self->status_message(">>> Beginning MapToBam conversion at $now for library: $library .");
	 
		$self->status_message("MapToBam inputs for library: $library");
		$self->status_message("maq_version: ".$self->aligner_version);
		$self->status_message("map_file: ".$map_file);
		$self->status_message("lib_tag: ".$library); 
		my $map_to_bam = Genome::Model::Tools::Maq::MapToBam->create(
			    use_version => $self->aligner_version,
			    map_file => $map_file,
			    lib_tag => $library,
		);
		my $map_to_bam_rv =  $map_to_bam->execute;
		unless ($map_to_bam_rv == 1) {
			$self->error_message("MapToBam failed for library: $library with return value: $map_to_bam_rv");
		}
		$now = UR::Time->now;
		$self->status_message("<<< Ending MapToBam conversion at $now for library: $library .");
	
	}#end library loop 


    $self->status_message("*** Dedup process completed ***");
    }#end parallelized item loop

   return 1;
} #end execute




1;
