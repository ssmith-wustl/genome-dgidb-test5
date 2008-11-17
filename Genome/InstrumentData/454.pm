package Genome::InstrumentData::454;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::454 {
    is  => 'Genome::InstrumentData',
    has => [
    sff_file => {
        doc => 'The sff file associated with the 454 instrument data',
        calculate_from => [qw/ resolve_full_path id /],
        calculate => q| return sprintf('%s/%s.sff', $resolve_full_path, $id); |,
    },
    #< Run Region 454 from DW Attrs >#
    _run_region_454     => {
        doc => '454 Run Region from LIMS.',
        is => 'GSC::RunRegion454',
        calculate => q| GSC::RunRegion454->get($id); |,
        calculate_from => [qw/ id  /]
    },
    region_id           => { via => "_run_region_454" },
    library_name        => { via => "_run_region_454" },
    total_reads         => { via => "_run_region_454", to => "total_key_pass" },
    is_paired_end       => { via => "_run_region_454", to => "paired_end" },
    limit_regions       => { via => "_run_region_454", to => "region_number" }, # legacy RunChunk
    ],
};

sub _default_full_path {
    my $self = shift;
    return sprintf('%s/%s/%s', $self->_data_base_path, $self->run_name, $self->id);
}

#< Dump to File System >#
sub dump_to_file_system {
    my $self = shift;

    $self->create_data_directory_and_link 
        or return;

    unless ( -e $self->sff_file ) {
        # THIS COULD SAVE SPACE BUT NOT SURE IF IT WILL WORK OR HOW TO HANDLE WHEN THE FILE DOESN'T EXIST
        # The file may already exist on the filesystem.  If so, create a symlink
        #my $sff_file_location = $run_region_454->sff_filesystem_location;
        #if (-e $sff_file_location) {
        #    unless (symlink($sff_file_location,$self->sff_file)) {
        #        $self->error_message("Failed to create symlink '". $self->sff_file ."' to '$sff_file_location'");
        #        return;
        #    }
        #} else {
            unless ( $self->_run_region_454->dump_sff(filename => $self->sff_file) ) {
                $self->error_message('Failed to dump sff_file to '. $self->sff_file);
                return;
            }
        #}
    }
    
    return 1;
}

1;

#$HeadURL$
#$Id$
