package Genome::Model::Event::Build::ReferenceAlignment::DeduplicateLibraries::WholeMap;

#REVIEW fdu 11/18/2009
#This is an obsolete module that is not used by G::M::C::B::R::D::Maq
#anymore. Remove it soon. And also this module should have been placed 
#as genome model tool when firstly implemented.

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::DeduplicateLibraries::WholeMap {
    is => ['Command'],
    has_input => [
                  whole_map_file => {
                                                 is => 'String',
                                                 doc => 'A whole, non-deduplicated map file.'
                                             },
                  ignments => {
                                 is => 'Array',
                                 doc => 'Array ref of alignment files.'
                             },
                  aligner_version => {
                                      is => 'Text',
                                      doc => 'The maq read aligner version used',
                                  },
    ],
    has_param => [
                  lsf_resource => {
                                   default_value => 'select[model!=Opteron250 && type==LINUX64] rusage[mem=4000]',
                               },
    ],
    has_output => [
                   output_file => { 
                                   is => 'String',
                                   is_optional => 1,
                               }
    ],
};

sub make_whole_map_file {
    my $self=shift;
    my $maplist=shift;

    $self->status_message('Maplist: '.$maplist);

    my $final_file = $self->whole_map_file;
    $self->status_message('Whole map file: '. $final_file );

    if (-s $final_file) {
        $self->status_message('Whole map file exists: '. $final_file);
    } else {
        my $tmp_file = '/tmp/whole.map';
        my $aligner_version = $self->aligner_version;
        my $maq_cmd = "gmt maq vmerge --version=$aligner_version --maplist $maplist --pipe $tmp_file &";
        $self->status_message("Executing:  $maq_cmd");
        my $rv = Genome::Utility::FileSystem->shellcmd(cmd=>$maq_cmd);
        unless ($rv) {
            $self->error_message("Command had errors: $maq_cmd");
            return;
        }  
        my $start_time = time;
        until (-p "$tmp_file" or ( (time - $start_time) > 100) )  {
            sleep(5);
        }
        unless (-p "$tmp_file") {
            die "failed to make intermediate file for whole map $!";
        }
        $self->status_message("Streaming into file $tmp_file.");

        Genome::Utility::FileSystem->cat(
                                         input_files => [$tmp_file],
                                         output_file => $final_file,
                                     );
    }
    return $final_file;
}

sub execute {
    my $self=shift;

    my $now = UR::Time->now;
    $self->status_message("Executing WholeMap.pm at $now");

    my @maps;
    if ( ref($self->alignments) ne 'ARRAY' ) {
        die('Failed to pass array ref of alignments to WholeMap.pm');
    } else {
        @maps = @{$self->alignments};   	#the parallelized code will only receive a list of one item.
    }
    my $maplist = Genome::Utility::FileSystem->create_temp_file_path('whole.maplist');
    my $fh = IO::File->new($maplist,'w');
    unless ($fh) {
        $self->error_message("Failed to create filehandle for '$maplist':  $!");
        return;
    }
    my $cnt=0;
    for my $input_alignment (@maps) {
        unless(-f $input_alignment) {
            $self->error_message("Expected $input_alignment not found");
            return;
        }
        $cnt++;
        print $fh $input_alignment ."\n";
    }
    $self->status_message("$cnt map files");
    $fh->close;
    $now = UR::Time->now;
    $self->status_message(">>> Starting make_whole_map_file() at $now.");
    my $map_file =  $self->make_whole_map_file($maplist);
    $now = UR::Time->now;
    $self->status_message("<<< Completed make_whole_map_file() at $now.");

    unless($map_file) {
        $self->error_message("Something went wrong with 'make_whole_map_file'");
        return;
    }
    $self->status_message("*** WholeMap process completed ***");
    return 1;
}

1;
