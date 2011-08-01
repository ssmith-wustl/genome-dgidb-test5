package Genome::Model::Build::DeNovoAssembly::Soap;

use strict;
use warnings;

use Genome;
use Data::Dumper 'Dumper';
require Carp;

class Genome::Model::Build::DeNovoAssembly::Soap {
    is => 'Genome::Model::Build::DeNovoAssembly',
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    if ( not $self->is_imported ) {
        my $paired_ins_data_count = grep { $_->is_paired_end } $self->instrument_data;

        if ( $paired_ins_data_count == 0 ) {
            $self->error_message("No paired instrument data found");
            $self->delete;
            return;
        }
    }

    return $self;
}

sub is_imported {
    my $self = shift;
    if ( $self->processing_profile->assembler_name =~ /import/ ) {
        return 1;
    }
    return;
}

#general
sub soap_output_dir_and_file_prefix {
    return $_[0]->data_directory.'/'.$_[0]->file_prefix;
}

sub file_prefix {
    my $self = shift;
    #pga model output files are named with sra_sample_id _ center name
    if ($self->processing_profile->name =~ /\s+PGA$/) {
        if (not exists $self->{_SRA_SAMPLE_ID}) {
            $self->sra_sample_id_for_pga_imported_instrument_data;
        }
        return $self->{_SRA_SAMPLE_ID}.'_'.$self->center_name;
    }
    return Genome::Utility::Text::sanitize_string_for_filesystem( $self->model->subject_name ).'_'.$self->center_name;
}

#pga output files
sub pga_agp_file {
    return $_[0]->data_directory.'/'.$_[0]->file_prefix.'.agp';
}

sub pga_contigs_fasta_file {
    return $_[0]->data_directory.'/'.$_[0]->file_prefix.'.contigs.fa';
}

sub pga_scaffolds_fasta_file {
    return $_[0]->data_directory.'/'.$_[0]->file_prefix.'.scaffolds.fa';
}

# assembler
sub soap_config_file {
    return $_[0]->data_directory.'/config_file';
}

sub soap_scaffold_sequence_file {
    return $_[0]->data_directory.'/'.$_[0]->file_prefix.'.scafSeq';
}

sub soap_output_file_for_ext {
    return $_[0]->soap_output_dir_and_file_prefix.'.'.$_[1];
}

#post assemble files
sub contigs_fasta_file {
    return $_[0]->edit_dir.'/'.$_[0]->file_prefix.'.contigs.fa';
}

sub supercontigs_fasta_file {
    return $_[0]->edit_dir.'/'.$_[0]->file_prefix.'.scaffolds.fa';
}

sub supercontigs_agp_file {
    return $_[0]->edit_dir.'/'.$_[0]->file_prefix.'.agp';
}

#input files
sub assembler_forward_input_file_for_library_id {
    my ($self, $library_id) = @_;
    return $self->data_directory.'/'.$self->file_prefix.'.'.$library_id.'.forward.fastq';
}

sub assembler_reverse_input_file_for_library_id {
    my ($self, $library_id) = @_;
    return $self->data_directory.'/'.$self->file_prefix.'.'.$library_id.'.reverse.fastq';
}

sub assembler_fragment_input_file_for_library_id {
    my ($self, $library_id) = @_;
    return $self->data_directory.'/'.$self->file_prefix.'.'.$library_id.'.fragment.fastq';
}

#< end files >#

sub imported_srs_id {
    my ($self, $instrument_data) = $_;
    
}

sub read_processor_output_files_for_instrument_data {
    my ($self, $instrument_data) = @_;

    my $library_id = $instrument_data->library_id;
    $library_id = 'unknown' if not defined $library_id;
    if ( $instrument_data->is_paired_end ) {
        return ( 
            $self->assembler_forward_input_file_for_library_id($library_id),
            $self->assembler_reverse_input_file_for_library_id($library_id),
        );
    }
    else {
        return $self->assembler_fragment_input_file_for_library_id($library_id);
    }
}

sub libraries_with_existing_assembler_input_files {
    my $self = shift;

    my @instrument_data = $self->instrument_data;
    if ( not @instrument_data ) {
        $self->error_message('No instrument data found for .'.$self->description);
        return;
    }

    my %params = $self->processing_profile->assembler_params_as_hash;    

    my @libraries;
    for my $instrument_data ( @instrument_data ) {
        my $library_id = $instrument_data->library_id || 'unknown';
        next if grep { $library_id eq $_->{library_id} } @libraries;
	#Over ride ins-data insert size if inert size is specified in pp assembler param .. if no ins-data insert size defined
	#and no pp specified insert size, die
	my $insert_size = ( exists $params{'insert_size'} ) ? $params{'insert_size'} : $instrument_data->median_insert_size;
	unless ( $insert_size ) {
	    Carp::confess("Failed to set insert size for library id: $library_id.  Neither instrument data is set in assembler params no found instrument data insert size");
	}
        my %files = $self->existing_assembler_input_files_for_library_id($library_id);
        next if not %files;
        my %library = (
            library_id => $library_id,
            insert_size => $insert_size,
        );
        $library{paired_fastq_files} = $files{paired_fastq_files} if exists $files{paired_fastq_files};
        $library{fragment_fastq_file} = $files{fragment_fastq_file} if exists $files{fragment_fastq_file};
        push @libraries, \%library;
    }

    return @libraries;
}

sub existing_assembler_input_files_for_library_id {
    my ($self, $library_id) = @_;

    if ( not defined $library_id ) {
        $self->error_message('No library id given to get existing assembler input files');
        return;
    }

    my %files;
    my $forward_fastq_file = $self->assembler_forward_input_file_for_library_id($library_id);
    my $reverse_fastq_file = $self->assembler_reverse_input_file_for_library_id($library_id);
    my $fragment_fastq_file = $self->assembler_fragment_input_file_for_library_id($library_id);

    if ( not -s $forward_fastq_file and not -s $reverse_fastq_file and not -s $fragment_fastq_file ) {
        $self->error_message("No assembler input fastqs exist for library ($library_id).");
        return;
    }

    if ( -s $forward_fastq_file and -s $reverse_fastq_file ) {
        $files{paired_fastq_files} = [ $forward_fastq_file, $reverse_fastq_file ];
    }
    elsif ( -s $forward_fastq_file ) { # forward exists, reverse does not
        $self->error_message("Foward fastq ($forward_fastq_file) for library ($library_id) exists, but the reverse ($reverse_fastq_file) does not.");
        return;
    }
    elsif ( -s $reverse_fastq_file ) { # reverse exists, forward does not
        $self->error_message("Reverse fastq ($reverse_fastq_file) for library ($library_id) exists, but the forward ($forward_fastq_file) does not.");
        return;
    }

    if ( -s $fragment_fastq_file ) {
        $files{fragment_fastq_file} = $fragment_fastq_file;
    }

    return %files;
}

sub existing_assembler_input_files {
    my $self = shift;

    my @libraries = $self->libraries_with_existing_assembler_input_files;
    return if not @libraries;

    my @files;
    for my $library ( @libraries ) {
        push @files, @{$library->{paired_fastq_files}} if exists $library->{paired_fastq_files};
        push @files, $library->{fragment_fastq_file} if exists $library->{fragment_fastq_file};
    }

    return @files;
}

sub sra_sample_id_for_pga_imported_instrument_data {
    my $self = shift;
    my @sra_ids;
    foreach my $data ($self->instrument_data) {
        unless ($data->subclass_name eq 'Genome::InstrumentData::Imported') {
            $self->error_message("Called for sra id on none imported instrument data, subclass was: ".$data->subclass_name);
            return;
        }
        unless ($data->sra_sample_id) {
            $self->error_message("Failed to get sra_sample_id for instrument data: ID ".$data->id);
            return;
        }
        my $sra_id = $data->sra_sample_id;
        push @sra_ids, $sra_id unless grep (/^$sra_id$/, @sra_ids);
    }
    if (@sra_ids > 1) {
        $self->error_message("Expected one but got multiple sra_sample_ids for instrument data: @sra_ids");
        return;
    }
    $self->{_SRA_SAMPLE_ID} = $sra_ids[0];

    return $sra_ids[0];
}

#<ASSEMBLE>#
sub assembler_rusage {
    my $self = shift;

    if ( $self->is_imported ) {
        return "-R 'select[type==LINUX64] rusage[internet_download_mbps=100] span[hosts=1]'";
    }

    my $mem = 30000;
    my $queue = 'apipe';
    $queue = 'alignment-pd' if $self->run_by eq 'apipe-tester';
    return "-q $queue -n 4 -R 'span[hosts=1] select[type==LINUX64 && mem>$mem] rusage[mem=$mem]' -M $mem".'000';
}

sub assembler_params {
    my $self = shift;

    my %params = $self->processing_profile->assembler_params_as_hash;
    $params{version} = $self->processing_profile->assembler_version;
    $params{output_dir_and_file_prefix} = $self->soap_output_dir_and_file_prefix;

    if ( $self->is_imported ) {
        my $location = '/WholeMetagenomic/03-Assembly/PGA/'. $self->model->subject_name.'_'.$self->model->center_name;
        $params{import_location} = $location;
    }
    else {
        # config params
        $params{config_file} = $self->soap_config_file;
        my %default_config_params = $self->_assembler_config_params_and_defaults;
        for my $param ( keys %default_config_params ) {
            delete $params{$param};
        }
        my $cpus = $self->processing_profile->get_number_of_cpus;
        $params{cpus} = $cpus;
    }

    return %params;
}

sub _assembler_config_params_and_defaults {
    return (
        max_rd_len => 120,
        reverse_seq => 0,
        asm_flags => 3,
        pair_num_cutoff => 2,
        map_len => 60,
        insert_size => undef, # avg_ins
    );
}

sub before_assemble {
    my $self = shift;

    $self->status_message("Soap config file");

    my %params = $self->processing_profile->assembler_params_as_hash;
    my %default_config_params = $self->_assembler_config_params_and_defaults;
    my %config_params;
    for my $param ( keys %default_config_params ) {
        $config_params{$param} = ( defined $params{$param} )
        ? $params{$param} 
        : $default_config_params{$param};
    }

    my $avg_ins = delete $config_params{insert_size};
    if ( defined $avg_ins ) {  
        $self->status_message("Using user defined insert size, will ignore calculated insert size defined in instrument data");
    }

    $self->status_message('Getting libraries with input files');
    my @libraries = $self->libraries_with_existing_assembler_input_files;
    if ( not @libraries ) {
        $self->error_message("No assembler input files were found for libraries");
        return;
    }

    my $config = "max_rd_len=".delete($config_params{max_rd_len})."\n";
    my $lib_config = join("\n", '[LIB]', map { $_.'='.$config_params{$_} } keys %config_params);
    $lib_config .= "\n";

    $self->status_message('Add libraries to config');
    for my $library ( @libraries ) {
    $self->status_message('Library: '.$library->{library_id});
        $config .= $lib_config;
        $config .= 'avg_ins=';
        $config .= ( defined $avg_ins ) ? $avg_ins : $library->{insert_size}; # use given avg_ins or from lib
        $config .= "\n";
        if ( exists $library->{paired_fastq_files} ) { 
            $config .= 'q1='.$library->{paired_fastq_files}->[0]."\n";
            $config .= 'q2='.$library->{paired_fastq_files}->[1]."\n";
        }

        if ( exists $library->{fragment_fastq_file} ) {
            $config .= 'q='.$library->{fragment_fastq_file}."\n";
        }
    }
    $self->status_message('Add libraries to config...OK');

    my $config_file = $self->soap_config_file;
    unlink $config_file if -e $config_file;
    $self->status_message("Soap config file: ".$config_file);
    my $fh = eval { Genome::Sys->open_file_for_writing( $config_file ); };
    if ( not $fh ) {
        $self->error_message("Can not open file ($config_file) for writing $@");
        return;
    }
    $fh->print( $config );
    $fh->close;

    $self->status_message("Soap config file...OK");

    return $config_file;
}
#</ASSEMBLE>#

#for build diff testing
sub files_ignored_by_diff { #all output files .. will differ slightly each time .. this is okay
    return qw/ build.xml Log config_file
    H_KT-185-1-0089515594_WUGC.Arc
    H_KT-185-1-0089515594_WUGC.ContigIndex
    H_KT-185-1-0089515594_WUGC.contig
    H_KT-185-1-0089515594_WUGC.edge
    H_KT-185-1-0089515594_WUGC.gapSeq
    H_KT-185-1-0089515594_WUGC.kmerFreq
    H_KT-185-1-0089515594_WUGC.links
    H_KT-185-1-0089515594_WUGC.markOnEdge
    H_KT-185-1-0089515594_WUGC.newContigIndex
    H_KT-185-1-0089515594_WUGC.path
    H_KT-185-1-0089515594_WUGC.peGrads
    H_KT-185-1-0089515594_WUGC.preArc
    H_KT-185-1-0089515594_WUGC.preGraphBasic
    H_KT-185-1-0089515594_WUGC.readInGap
    H_KT-185-1-0089515594_WUGC.readOnContig
    H_KT-185-1-0089515594_WUGC.scaf
    H_KT-185-1-0089515594_WUGC.scafSeq
    H_KT-185-1-0089515594_WUGC.scaf_gap
    H_KT-185-1-0089515594_WUGC.updated.edge
    H_KT-185-1-0089515594_WUGC.vertex
    H_KT-185-1-0089515594_WUGC.agp
    H_KT-185-1-0089515594_WUGC.contigs.fa
    H_KT-185-1-0089515594_WUGC.scaffolds.fa
    /;
}

sub metrics_ignored_by_diff {
    return ('assembly length', 'average contig length', 'average contig length gt 300',
	    'average supercontig length', 'average supercontig length gt 300',
	    'config_file', 'contigs', 'n50 contig length', 'n50 supercontig length',
	    'n50_contig_length_gt_300', 'n50_supercontig_length_gt_300');
}

sub dirs_ignored_by_diff {
    return qw/ logs reports edit_dir /;
}

sub regex_files_for_diff {
    return qw/ H_KT-185-1-0089515594_WUGC.2852968107.forward.fastq H_KT-185-1-0089515594_WUGC.2852968107.reverse.fastq /;
}

1;

