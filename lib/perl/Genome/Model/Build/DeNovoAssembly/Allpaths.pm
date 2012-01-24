package Genome::Model::Build::DeNovoAssembly::Allpaths;;

use strict;
use warnings;
use Genome;

class Genome::Model::Build::DeNovoAssembly::Allpaths {
    is => 'Genome::Model::Build::DeNovoAssembly',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return if not $self;

    my $jumping_count;
    my $sloptig_count;
    foreach my $i_d ($self->instrument_data) {
        if ($self->_instrument_data_is_jumping($i_d)) {
            $jumping_count++;
        }

        if ($self->_instrument_data_is_sloptig($i_d)) { 
            $sloptig_count++;
        }
    }

    if ($jumping_count == 0) {
        $self->error_message("No jumping library instrument data found");
        $self->delete;
        return;
    }

    if ($sloptig_count == 0) {
        $self->error_message("No sloptig library instrument data found");
        $self->delete;
        return;
    }
    return $self;
}

#Override base class method
sub stats_file {
    my $self = shift;
    return $self->data_directory."/metrics.out";
}

sub _instrument_data_is_jumping {
    my ($self, $instrument_data) = @_;
    if ($instrument_data->read_orientation and $instrument_data->original_est_fragment_size
        and $instrument_data->final_est_fragment_size
        and $instrument_data->read_orientation eq "reverse_forward"
        and $instrument_data->original_est_fragment_size > $instrument_data->final_est_fragment_size) {
        return 1;
    }
    else {
        return 0;
    }
}

sub _instrument_data_is_sloptig {
    my ($self, $instrument_data) = @_;
     if (!$self->_instrument_data_is_jumping($instrument_data)) {
        return 1;
    }
    else {
        return 0;
    }
}

sub _allpaths_in_group_file {
    return $_[0]->data_directory."/in_group.csv";
}

sub _allpaths_in_libs_file {
    return $_[0]->data_directory."/in_libs.csv";
}

sub before_assemble {
    my $self = shift;
    $self->status_message("Allpaths config files");

    my %params = $self->processing_profile->assembler_params_as_hash;

    $self->status_message("Generating Allpaths in_group.csv and in_libs.csv");
    my $in_group = "file_name,\tlibrary_name,\tgroup_name";

    foreach my $instrument_data ($self->instrument_data) {
        if ($self->_instrument_data_is_sloptig($instrument_data)) {
            $in_group = $in_group."\n".$self->data_directory."/".$instrument_data->id.".*.sloptig.fastq,\t".$instrument_data->library_name.",\t".$instrument_data->id;
        }
        elsif ($self->_instrument_data_is_jumping($instrument_data)) {
            $in_group = $in_group."\n".$self->data_directory."/".$instrument_data->id.".*.jumping.fastq,\t".$instrument_data->library_name.",\t$instrument_data->id";
        }
    }

    my $in_libs = "library_name,\tproject_name,\torganism_name,\ttype,\tpaired,\tfrag_size,\tfrag_stddev,\tinsert_size,\tinsert_stddev,\tread_orientation,\tgenomic_start,\tgenomic_end";

    my %libs_seen;
    foreach my $instrument_data ($self->instrument_data) {
        if (! $libs_seen{$instrument_data->library_id}){
            my $lib = Genome::Library->get($instrument_data->library_id);
            if ($self->_instrument_data_is_sloptig($instrument_data)) {
                my $fragment_std_dev = $instrument_data->final_est_fragment_std_dev;
                $in_libs = $in_libs."\n".$lib->name.",\tproject_name,\t".$lib->species_name.",\tfragment,\t1,\t".$instrument_data->final_est_fragment_size.",\t".$fragment_std_dev.",\t,\t,\tinward,\t0,\t0";
            }
            elsif ($self->_instrument_data_is_jumping($instrument_data)){
                my $fragment_std_dev = $instrument_data->original_est_fragment_std_dev;
                $in_libs = $in_libs."\n".$lib->name.",\tproject_name,\t".$lib->species_name.",\tjumping,\t1,\t,\t,\t".$instrument_data->original_est_fragment_size.",\t".$fragment_std_dev.",\toutward,\t0,\t0";
            
            }
        }
        $libs_seen{$instrument_data->library_id} = 1;
    }

    my $in_group_file = $self->_allpaths_in_group_file;
    unlink $in_group_file if -e $in_group_file;
    $self->status_message("Allpaths in_group file: ".$in_group_file);
    my $fh = eval { Genome::Sys->open_file_for_writing( $in_group_file); };
    if (not $fh) {
        $self->error_message("Can not open file ($in_group_file) for writing $@");
        return;
    }
    $fh->print($in_group);
    $fh->close;
    $self->status_message("Allpaths in_group file...OK");

    my $in_libs_file = $self->_allpaths_in_libs_file;
    unlink $in_libs_file if -e $in_libs_file;
    $self->status_message("Allpaths in_libs file: ".$in_libs_file);
    $fh = eval { Genome::Sys->open_file_for_writing( $in_libs_file); };
    if (not $fh) {
        $self->error_message("Can not open file ($in_libs_file) for writing $@");
        return;
    }
    $fh->print($in_libs);
    $fh->close;
    $self->status_message("Allpaths in_libs file...OK");
}

sub assembler_params {
    my $self = shift;

    my %default_params = (
        run => "run",
        sub_dir => "test",
        reference_name => "sample",
    );
    my %params = $self->processing_profile->assembler_params_as_hash;

    foreach my $param (keys %default_params) {
        if (! defined $params{$param}) {
            $params{$param} = $default_params{$param};
        }
    }

    $params{version} = $self->processing_profile->assembler_version;
    $params{pre} = $self->data_directory;
    $params{in_group_file} = $self->_allpaths_in_group_file;
    $params{in_libs_file} = $self->_allpaths_in_libs_file;

    return %params;
}

sub assembler_rusage {
    my $self = shift;
    my $mem = 494000;
    $mem = 92000 if $self->run_by eq 'apipe-tester';
    my $queue = 'assembly';
    $queue = 'alignment-pd' if $self->run_by eq 'apipe-tester';
    return "-q $queue -n 4 -R 'span[hosts=1] select[type==LINUX64 && mem>$mem] rusage[mem=$mem]' -M $mem".'000';
}

sub existing_assembler_input_files {
    my $self = shift;
    my @files;
    foreach my $i_d ($self->instrument_data) {
        push(@files, $self->read_processor_output_files_for_instrument_data($i_d));
    }
    return @files;
}

sub read_processor_output_files_for_instrument_data {
    my $self = shift;
    my $instrument_data = shift;

    if ($instrument_data->is_paired_end) {
        if ($self->_instrument_data_is_jumping($instrument_data)){
            return ($self->data_directory."/".$instrument_data->id.".forward.jumping.fastq",
                    $self->data_directory."/".$instrument_data->id.".reverse.jumping.fastq");
        }
        elsif ($self->_instrument_data_is_sloptig($instrument_data)){
            return ($self->data_directory."/".$instrument_data->id.".forward.sloptig.fastq",
                    $self->data_directory."/".$instrument_data->id.".reverse.sloptig.fastq");
        }
    }

    else {
        return $self->data_directory."/".$instrument_data->id.".fragment.fastq";;
    }
}

1;

