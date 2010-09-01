package Genome::Model::Tools::Pindel::RunPindel;

use warnings;
use strict;

use Genome;
use Workflow;
use Carp;
use FileHandle;
use Data::Dumper;
use List::Util qw( max );

class Genome::Model::Tools::Pindel::RunPindel {
    is => ['Command'],
    has => [
        reference_fasta => {
            is  => 'String',
            default => Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/all_sequences.fa',
            doc => 'the reference fasta',
        },
        reads_file_one_end => {
            is => 'String',
            is_input => '1',
            default=>1,
            doc => 'The input reads file containing one end mapped reads on which to run pindel.',
        },
        reads_file_sw => {
            is => 'String',
            is_input => '1',
            default=>1,
            doc => 'The input reads file containing smith-waterman reads on which to run pindel.',
        },
        reads_file_merged => {
            is => 'Integer',
            is_input => '1',
            default=>1,
            doc => 'The location in which to store the concatination of the two reads files. This is hacky but pindel needs a file.',
        },
        output_insertion => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The pindel output containing insertion events',
        },
        output_deletion => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The pindel output containing deletion events',
        },
        output_di => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The pindel output containing deletion-insertion events',
        },
        model_id => {
            is  => 'Integer',
            is_input => '1',
            is_output => '1',
            doc => 'The model id from which to calculate average insert size',
        },
#        insert_size => {
#            is => 'Integer',
#            default => '200', # FIXME this should be calculated from chris' code he sent on 3/4
#        },
        skip_if_output_present => {
            is => 'Boolean',
            is_optional => 1,
            is_input => 1,
            default => 0,
            doc => 'enable this flag to shortcut through annotation if the output_file is already present. Useful for pipelines.',
        },
        pindel_location => {
            default => '/gsc/bin/pindel',
        },
        # Make workflow choose 64 bit blades
        lsf_resource => {
            is_param => 1,
            default_value => "-M 12000000 -R 'select[type==LINUX64 && mem>12000] rusage[mem=12000] span[hosts=1]'",
        },
        lsf_queue => {
            is_param => 1,
            default_value => 'long'
        }, 
      ],
};

sub help_brief {
    "Runs pindel on the specified reads file. This file must be formatted correctly for pindel (such as by running gmt pindel format-reads).";
}

sub help_synopsis {
    return <<"EOS"
gmt pindel run-pindel --reads-file formatted_reads --output-insertion ins.out --output-deletion del.out --output-di di.out --model-id 12345
gmt pindel run-pindel --reads formatted_reads --output-ins ins.out --output-del del.out --output-di di.out --model 12345
EOS
}

sub help_detail {                           
    return <<EOS 
Runs pindel on the specified reads file. This file must be formatted correctly for pindel (such as by running gmt pindel format-reads).
EOS
}

sub execute {
    my $self = shift;
    $DB::single = $DB::stopper;

    # test architecture to make sure we can run
    unless (`uname -a` =~ /x86_64/) {
       $self->error_message("Must run on a 64 bit machine");
       die;
    }

    # Skip if output files exist
    if (($self->skip_if_output_present)&&(-s $self->output_insertion)&&(-s $self->output_deletion)) {
        $self->status_message("Skipping execution: Output is already present and skip_if_output_present is set to true");
        return 1;
    }
    
    unless(-s $self->reads_file_one_end && -s $self->reads_file_one_end) {
        $self->error_message("Reads file contains less than 20bytes");
        return;
    }

    unless(-s $self->reference_fasta) {
        $self->error_message("reference fasta " . $self->reference_fasta . " not found");
        return;
    }

    $self->cat_reads_files;

    my $insert_size = $self->calculate_average_insert_size;
    
    my $cmd = $self->pindel_location . " " . $self->reference_fasta . " " . $self->reads_file_merged . " " . $insert_size . " " . $self->output_insertion . " " . $self->output_deletion . " " . $self->output_di . " ";

    # We do not check output_files because we accept that at least di may not be present
    my $result = Genome::Utility::FileSystem->shellcmd(cmd => $cmd, input_files => [$self->reads_file_merged]);

    # need to die here so workflow correctly sees a failure
    unless ($result == 1) {
        $self->error_message("Received nonzero exit code from pindel execution");
        die;
    }

    return 1;
}

# Hackidy hack hack
sub cat_reads_files {
    my $self = shift;

    my $return = system("cat " . $self->reads_file_sw . " " . $self->reads_file_one_end . " > " . $self->reads_file_merged);

    unless ($return == 0) {
        $self->error_message("Got nonzero exit code when catting reads files together. Something is wrong.");
        die;
    }
    
    return 1;
}

# Calculates the average insert size according to the align reads events of the last succeeded build for a model
sub calculate_average_insert_size {
    my $self = shift;

    my $model = Genome::Model::ReferenceAlignment->get($self->model_id);
    unless ($model) {
        $self->error_message("Could not obtain a valid reference alignment model from model id " . $self->model_id);
        die;
    }
    
    my $last_succeeded_build = $model->last_succeeded_build;
    unless ($last_succeeded_build) {
        $self->error_message("Could not obtain a last succeeded build from model id " . $self->model_id);
        die;
    }

    my @events = Genome::Model::Event->get(event_type => 
        {operator => 'like', value => '%align-reads%'},
        build_id => $last_succeeded_build,
        event_status => 'Succeeded',
        model_id => $self->model_id,
    );
    unless (@events) {
        $self->error_message("Could not find any align-reads events from build id " . $last_succeeded_build->build_id);
        die;
    }

    my @idas = map { $_->instrument_data_assignment } @events;
    unless (@idas) {
        $self->error_message("Could not find instrument data assignments from align-reads events");
        die;
    }

    my ($total, $count);
    for my $ida (@idas) {
        my $id = $ida->instrument_data;
        unless(defined($id)){
            $self->error_message("Could not get instrument-data for instrument-data assignment.\n".Data::Dumper::Dumper($ida));
            die $self->error_message;
        }
 
        # throw away junk (instrument data with no median insert size or some junk value for it)
        if( (defined $id->median_insert_size) && ($id->median_insert_size > 0) ) {
            $count++;
            $total+=$id->median_insert_size;
        }
    }
    my $avg = int($total/$count);

    return $avg;
}
