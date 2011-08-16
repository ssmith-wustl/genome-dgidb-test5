package Genome::InstrumentData::Command::Import::TcgaBam;

use strict;
use warnings;

use Genome;

require File::Basename;

class Genome::InstrumentData::Command::Import::TcgaBam {
    is  => 'Genome::InstrumentData::Command::Import',
    has => [
        original_data_path => {
            is => 'Text',
            doc => 'original data path of import data file',
        },
        tcga_name => {
            is => 'Text',
            doc => 'TCGA name for imported file',
        },
        target_region => {
            is => 'Text',
            doc => 'Provide the target region set name (capture) or \'none\' (whole genome or RNA/cDNA)',
        },
        remove_original_bam => {
            is => 'Boolean',
            doc => 'By uncluding this in your command, the tool will remove (delete!) the original bam file after importation, without warning.',
            default => 0,
            is_optional => 1,
        },
        no_md5 => {
            is => 'Boolean',
            default => 0,
            is_optional => 1,
        },
        import_source_name => {
            is => 'Text',
            doc => 'source name for imported file, like broad',
            is_optional => 1,
        },
        description  => {
            is => 'Text',
            doc => 'general description of import data, like which software maq/bwa/bowtie to used to generate this data',
            is_optional => 1,
        },
        read_count  => {
            is => 'Number',
            doc => 'total read count of import data',
            is_optional => 1,
        },
        base_count  => {
            is => 'Number',
            doc => 'total base count of import data',
            is_optional => 1,
        },
        reference_sequence_build => { 
            calculate => q| return Genome::Model::Build::ImportedReferenceSequence->get(101947881); |,
            is_param => 0,
            doc => 'The reference sequence build the data was aligned against, currently "NCBI-build-36".',
        },
        _model => { is_optional => 1, },
        _inst_data => { is_optional => 1, },
        import_instrument_data_id => { via => '_inst_data', to => 'id', },
        _allocation => { via => '_inst_data', to => 'disk_allocations', },
        _absolute_path => { via => '_allocation', to => 'absolute_path', },
        _new_bam => { 
            calculate_from => [qw/ _absolute_path /], 
            calculate => q| $_absolute_path.'/all_sequences.bam' |,
        },
        _new_md5 => { 
            calculate_from => [qw/ _new_bam /], 
            calculate => q| $_new_bam.'.md5' |,
        },
    ],
    doc => 'create an instrument data AND and alignment for a BAM',
};

sub help_detail {
    return <<HELP;
    This command imports a BAM for a TCGA patient. Workflow:
    * creates an instrument data
    * copies the BAM into the allocated spaace of the instruemt data
    * validates the MD5 of the BAM (optional)
    * creates a model and requests a build
HELP
}

sub execute {
    my $self = shift;

    # Validate BAM
    my $bam_ok = $self->_validate_bam;
    return if not $bam_ok;

    # Create inst data
    my $inst_data = $self->_create_imported_instrument_data;
    return if not $inst_data;

    # Copy and create md5 at the same time w/ tee
    my $copy = $self->_copy_and_generate_md5;
    if ( not $copy ) {
        $self->_bail;
        return;
    }

    # Validate copied BAM
    my $validate = $self->_validate_copied_bam;
    if ( not $validate ) {
        $self->_bail;
        return;
    }

    # Add stats to the instrument-data taken from flagstat, etc
    unless($self->_add_stats){
        die $self->error_message("Could not complete flagstat operation on imported bam");
    }

    # Rm Original BAM
    if($self->remove_original_bam){
        $self->_remove_original_bam; # no error check
    }

    $self->_create_model_and_request_build; # no error check, prints messages

    $self->status_message("Importation of BAM completed successfully.");
    $self->status_message("Your instrument-data id is ".$self->import_instrument_data_id);

    return 1;
}

sub _validate_bam {
    my $self = shift;

    my $bam = $self->original_data_path;
    if ( not -s $bam ) {
        $self->error_message('BAM does not exist: '.$bam);
        return;
    }

    if ( $bam !~ /\.bam$/ ) { # why?
        $self->error_message('BAM does not have extension ".bam": '.$bam);
        return;
    }

    return 1;
}

sub _validate_md5 {
    my $self = shift;

    $self->status_message('Validate BAM MD5...');

    my $bam = $self->original_data_path;
    my $md5_file = $bam . ".md5";
    if ( not -s $md5_file ) {
        $self->error_message("Did not find md5 file ($md5_file) for bam ($bam)");
        return;
    }

    $self->status_message("Getting BAM MD5 from file: $md5_file");
    my $md5_fh = eval{ Genome::Sys->open_file_for_reading($md5_file); };
    if ( not $md5_fh ) {
        print Data::Dumper::Dumper($md5_fh);
        $self->error_message("Cannot open BAM MD5 file ($md5_file): $@");
        return;
    }
    my $line = $md5_fh->getline;
    chomp $line;
    my ($md5) = split(" ", $line);
    if ( not $md5 ) {
        $self->error_message('No MD5 in file: '.$md5_file);
        return;
    }
    $self->status_message("Got BAM MD5 from file: $md5");

    $self->status_message("Calculate MD5 for bam: $bam");
    $self->status_message("This may take a bit...");
    my $calculated_md5 = $self->_md5_for_file($bam);
    if ( not $calculated_md5 ) {
        $self->error_message("Failed to calculate md5 for BAM: $bam.");
        return;
    }
    $self->status_message("Calculated MD5: $calculated_md5");

    $self->status_message('Validate MD5...');
    if ( $md5 ne $calculated_md5 ) {
        $self->error_message("Calculated BAM MD5 ($calculated_md5) does not match MD5 from file ($md5)");
        return;
    }
    $self->status_message('Validate MD5...OK');

    return 1;
}

sub _md5_for_file {
    my ($self, $file) = @_;

    if ( not -e $file ) {
        $self->error_message("Cannot get md5 for non existing file: $file");
        return;
    }

    my ($md5) = split(/\s+/, `md5sum $file`);

    if ( not defined $md5 ) {
        $self->error_message("No md5 returned for file: $file");
        return;
    }

    return $md5;
}

sub _create_imported_instrument_data {
    my $self = shift;

    $self->status_message('Create imported instrument data...');

    my $tcga_name = $self->tcga_name;

    # Get or create library
    my $sample_importer = Genome::Sample::Command::Import::Tcga->create(
        name => $tcga_name,
    );
    if ( not $sample_importer ) {
        $self->error_message('Could not create TCGA sample importer to get or create library');
        return;
    }
    $sample_importer->dump_status_messages(1);
    if ( not $sample_importer->execute ) {
        $self->error_message('Could not execute TCGA sample importer to get or create library');
        return;
    }
    my $library = $sample_importer->_library;

    my $target_region;
    unless ($self->target_region eq 'none') {
        if ($self->validate_target_region) {
            $target_region = $self->target_region;
        } else {
            $self->error_message("Invalid target region " . $self->target_region);
            die $self->error_message;
        }
    }

    my $description = $self->description || "imported ".$self->import_source_name." bam, tcga name is ".$tcga_name;
    if($self->no_md5){
        $description = $description . ", no md5 file was provided with the import.";
    }
    my %params = (
        original_data_path => $self->original_data_path,
        sequencing_platform => "solexa",
        import_format => "bam",
        reference_sequence_build => $self->reference_sequence_build,
        library => $library,
        target_region_set_name => $target_region,
        description => $description,
    );
    my $import_instrument_data = Genome::InstrumentData::Imported->create(%params);  
    unless ($import_instrument_data) {
       $self->error_message('Failed to create imported instrument data for '.$self->original_data_path);
       return;
    }
    $self->_inst_data($import_instrument_data);

    my $instrument_data_id = $import_instrument_data->id;
    $self->status_message("Instrument data: $instrument_data_id is imported");

    my $kb_usage = $import_instrument_data->calculate_alignment_estimated_kb_usage;
    unless ($kb_usage) {
        $self->error_message('Cannot calculate kb usage for BAM: '.$self->original_data_path);
        $import_instrument_data->delete;
        return 1;
    }

    my $alloc_path = sprintf('alignment_data/imported/%s', $instrument_data_id);

    my %alloc_params = (
        disk_group_name     => 'info_alignments',
        allocation_path     => $alloc_path,
        kilobytes_requested => $kb_usage,
        owner_class_name    => $import_instrument_data->class,
        owner_id            => $import_instrument_data->id,
    );

    my $disk_alloc = Genome::Disk::Allocation->allocate(%alloc_params);
    unless ($disk_alloc) {
        $self->error_message("Failed to get disk allocation with params:\n". Data::Dumper::Dumper(%alloc_params));
        $import_instrument_data->delete;
        return 1;
    }
    $self->status_message("Alignment allocation created for $instrument_data_id .");

    $self->status_message('Create imported instrument data...OK');

    return $self->_inst_data;
}

sub _copy_and_generate_md5 {
    my $self = shift;

    $self->status_message("Copy BAM and generate MD5");

    my $bam = $self->original_data_path;
    my $new_bam = $self->_new_bam;
    my $new_md5 = $self->_new_md5;
    my $cmd = "tee $new_bam < $bam | md5sum > $new_md5";
    $self->status_message('Cmd: '.$cmd);
    my $eval = eval{ Genome::Sys->shellcmd(cmd => $cmd); };
    if ( not $eval ) {
        $self->status_message('Copy BAM and generate MD5 FAILED: '.$@);
        return;
    }

    $self->status_message("Copy BAM and generate MD5");

    return 1;
}

sub _validate_copied_bam {
    my $self = shift;

    $self->status_message('Validate copied BAM...');

    $self->status_message('Validate size...');
    my $bam = $self->original_data_path;
    my $bam_size = -s $bam;
    my $new_bam = $self->_new_bam;
    my $new_bam_size = -s $new_bam;
    if ( $bam_size != $new_bam_size ) {
        $self->error_message("Copied BAM ($new_bam) size ($new_bam_size) does not match original BAM ($bam) size ($bam_size)");
        return;
    }
    $self->status_message("Validate size OK: $bam_size v. $new_bam_size");

    if ( $self->no_md5 ) {
        $self->status_message('Validate copied BAM...OK');
        return 1;
    }

    $self->status_message('Validate MD5...');
    my $md5_file = $bam.".md5";
    if ( not -s $md5_file ) {
        $self->error_message("Did not find md5 file ($md5_file) for bam ($bam)");
        return;
    }
    my $md5 = $self->_get_md5_from_file($md5_file);
    return if not $md5;

    my $new_md5_file = $self->_new_md5;
    if ( not -s $md5_file ) {
        $self->error_message("Did not find md5 file ($new_md5_file) for copied bam ($new_bam)");
        return;
    }
    my $new_md5 = $self->_get_md5_from_file($new_md5_file);
    return if not $new_md5;

    if ( $md5 ne $new_md5 ) {
        $self->error_message("Copied BAM MD5 ($new_md5) does not match MD5 from file ($md5)");
        return;
    }
    $self->status_message('Validate MD5...OK');

    $self->status_message('Validate copied BAM...OK');

    return 1;
}

sub _get_md5_from_file {
    my ($self, $file) = @_;

    $self->status_message("Get MD5 from file: $file");

    my $fh = eval{ Genome::Sys->open_file_for_reading($file); };
    if ( not $fh ) {
        $self->error_message("Cannot open file ($file): $@");
        return;
    }
    my $line = $fh->getline;
    chomp $line;
    my ($md5) = split(" ", $line);
    if ( not $md5 ) {
        $self->error_message('No MD5 in file: '.$file);
        return;
    }

    $self->status_message("MD5 for file ($file): $md5");

    return $md5;
}

sub XX_rsync_bam {
    my $self = shift;

    my $bam = $self->original_data_path;
    my $new_bam = $self->_new_bam;
    $self->status_message("Rsync BAM from $bam to $new_bam");

    my $cmd = "rsync -acv $bam $new_bam";
    $self->status_message('Rsync cmd: '.$cmd);
    my $rsync = eval{ Genome::Sys->shellcmd(cmd => $cmd); };
    if ( not $rsync ) {
        $self->error_message('Rsync cmd failed: '.$@);
        $self->status_message('Removing disk allocation: '.$self->_allocation->id);
        unlink $new_bam if -e $new_bam;
        $self->_allocation->deallocate;
        $self->error_message('Removing instrument data: '.$self->_inst_data->id);
        $self->_inst_data->delete;
        return;
    }
    $self->status_message('Rync BAM...OK');

    return 1;
}
 
sub _bail {
    my $self = shift;

    $self->status_message('Copy BAM and generate MD5 FAILED: '.$@);
    $self->status_message('Removing disk allocation: '.$self->_allocation->id);
    my $new_bam = $self->_new_bam;
    unlink $new_bam if -e $new_bam;
    my $new_md5 = $self->_new_md5;
    unlink $new_md5 if -e $new_md5;
    $self->_allocation->deallocate;
    $self->status_message('Removing instrument data: '.$self->_inst_data->id);
    $self->_inst_data->delete;

    return 1;
}

sub _add_stats {
    my $self = shift;
    my $data = $self->_run_flagstat;
    my $inst_data = $self->_inst_data;
    $inst_data->read_count($data->{'total_reads'});
    $inst_data->fragment_count($data->{'total_reads'}*2);
    $inst_data->read_length($self->_read_length);
    $inst_data->base_count(int($inst_data->read_length) * int($inst_data->fragment_count));
    if($data->{'reads_paired_in_sequencing'} > 0){
        $inst_data->is_paired_end(1);
    }
    else {
        $inst_data->is_paired_end(0);
    }
    $self->_inst_data($inst_data);
    return 1;
}

sub _read_length {
    my $self = shift;
    $self->status_message("Now calculating read_length via gmt sam->read_length");
    my $sam = Genome::Model::Tools::Sam->create;
    my $read_length = $sam->read_length($self->_inst_data->bam_path);
    unless(defined($read_length)){
        die $self->error_message("Was not able to run gmt sam->read_length");
    }
    $self->status_message("Finished calculating read_length. read_length=".$read_length);
    return $read_length;
}

sub _run_flagstat {
    my $self = shift;
    unless(defined($self->_inst_data)){
        die $self->error_message("No instrument data found in self->_inst_data");
    }
    my $flagstat_file = $self->_inst_data->bam_path . ".flagstat";
    my $flagstat_object = Genome::Model::Tools::Sam::Flagstat->create( bam_file => $self->_inst_data->bam_path, output_file => $flagstat_file);
    unless(-s $flagstat_file){
        $self->status_message("Generating flagstat file now...");
        unless($flagstat_object->execute){
            die $self->error_message("Failed to run gmt sam flagstat");
        }
        $self->status_message("Flagstat file created");
    }
    my $flag_data = $flagstat_object->parse_file_into_hashref($flagstat_file);

    return $flag_data;
}

sub _remove_original_bam {
    my $self = shift;

    $self->status_message("Now removing original bam in 10 seconds.");
    for (1..10){
        sleep 1;
        print "slept for ".$_." seconds.\n";
    }
    my $bam_path = $self->original_data_path;
    unless(-s $bam_path){
        $self->error_message("Could not locate file to remove at ".$bam_path."\n");
        die $self->error_message;
    }
    unlink($bam_path);
    if(-s $bam_path){
        $self->error_message("Could not remove file at ".$bam_path."\n");
        $self->error_message("Check file permissions.");
    }else{
        $self->status_message("Original bam file has been removed from ".$bam_path);
    }

    return 1;
}

sub _create_model_and_request_build {
    my $self =  shift;

    $self->status_message('Create model and request build');

    my $refseq_build = $self->reference_sequence_build;
    $self->status_message('Reference build: '.$refseq_build->__display_name__);

    my $pp = Genome::ProcessingProfile::ReferenceAlignment->get(2580856);
    if ( not $pp ) {
        $self->error_message('Cannot find ref align processing profile for 2580856 to create model');
        return;
    }
    $self->status_message('Processing profile: '.$pp->name);

    my $sample = $self->_inst_data->sample;
    $self->status_message('Sample: '.$sample->name);

    my $model = Genome::Model::ReferenceAlignment->create(
        name => 'TCGA_BAM_PLACE_HOLDER',
        processing_profile => $pp,
        reference_sequence_build => $refseq_build,
        subject_id => $sample->id,
        subject_class_name => $sample->class,
        build_requested => 1,
        auto_assign_inst_data => 0,
    );
    if ( not $model ) {
        $self->error_message('Failed to create model');
        return;
    }
    my $name = $model->default_model_name;
    if ( not $name ) {
        $self->error_message('Failed to get default model name');
        $model->delete;
        return;
    }
    $model->name($name);
    $self->_model($model);

    my $add = $model->add_instrument_data( $self->_inst_data );
    if ( not $add ) {
        $self->error_message('Failed to add instrument data to model');
        $model->delete;
        return;
    }

    $self->status_message('Create model and request build...OK');

    return $model;
}

1;

