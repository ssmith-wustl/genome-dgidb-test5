package Genome::InstrumentData::Sanger;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Sanger {
    is  => 'Genome::InstrumentData',
    has_constant => [
        sequencing_platform => { value => 'sanger' },
    ],
    has => [
        #< Run from OLTP Attrs >#
        _gsc_run => {
                     doc => 'GSC Run from LIMS',
                     is => 'GSC::Run',
                     calculate_from => [qw/ id /],
                     calculate => q| GSC::Run->get($id); |,
        },
        sample_name => {
                        via   => 'attributes',
                        to    => 'value',
                        where => [
                                  entity_class_name => 'Genome::InstrumentData::Sanger',
                                  property_name     => 'sample_name',
                              ],
                        is_optional => 1,
                        is_mutable  => 1,
                    },     
        library_name => {
                         via   => 'attributes',
                         to    => 'value',
                         where => [
                                   entity_class_name => 'Genome::InstrumentData::Sanger',
                                   property_name     => 'library_name',
                               ],
                         is_optional => 1,
                         is_mutable  => 1,
                     },
        research_project => {
                 via   => 'attributes',
                 to    => 'value',
                 where => [
                       entity_class_name => 'Genome::InstrumentData::Sanger',
                       property_name     => 'research_project',
                   ],
             is_optional => 1,
             is_mutable  => 1,
             default_value => 'unknown',
        },
    ],
};

sub _data_base_path {
    return '/gscmnt/402/core/16S/info/instrument_data/';
}

#< Dump to File System >#
sub dump_to_file_system {
    my $self = shift;

    my $data_dir = $self->create_data_directory_and_link 
        or return;
        
    my $read_cnt = 0;
    my $reads = $self->_get_read_iterator
        or return;

    while ( my $read = $reads->next ) {
        $read_cnt++;
        my $scf_name = $read->default_file_name('scf');
        my $scf_file = sprintf('%s/%s.gz', $data_dir, $scf_name);
        next if -s $scf_file;
        unlink $scf_file if -e $scf_file; # remove empty file
        my $scf_fh = IO::File->new($scf_file, 'w');
        unless ( $scf_fh ) {
            $self->error_message("Can't open scf ($scf_file)\n$!");
            return;
        }
        $scf_fh->print( Compress::Zlib::memGzip($read->scf_content) );
        $scf_fh->close;
        $self->error_message("No scf content for $scf_name") unless -s $scf_file;
    }

    unless ( $read_cnt ) {
        $self->error_message( sprintf("No reads found for run (%s)", $self->run_name) );
        return;
    }

    return 1;
}

sub _get_read_iterator {
    my $self = shift;

    my $reads = App::DB::TableRow::Iterator->new(
        class => 'GSC::Sequence::Read',
        params => {
            prep_group_id => $self->run_name,
        },
    );

    unless ( $reads ) {
        $self->error_message( sprintf('Could not make read iterartor for run name (%s)', $self->run_name) );
        return;
    }

    return $reads;
}

sub get_library_summary {
    my $self = shift;
    return GSC::LibrarySummary->get(full_name => $self->library_name);
}

sub get_source_sample {
    my $self = shift;

    my $library_summary = $self->get_library_summary;
    unless ($library_summary) {
        return;
    }
    return $library_summary->get_source_sample;
}

sub get_population {
    my $self = shift;

    my $library_summary = $self->get_library_summary;
    unless ($library_summary) {
        return;
    }
    return $library_summary->get_population;
}

sub get_organism_taxon {
    my $self = shift;

    my $library_summary = $self->get_library_summary;
    unless ($library_summary) {
        return;
    }
    return $library_summary->get_organism_taxon;
}

1;

#$HeadURL$
#$Id$
