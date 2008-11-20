package Genome::InstrumentData::Sanger;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Sanger {
    is  => 'Genome::InstrumentData',
    has => [
    #< Run from OLTP Attrs >#
    _gsc_run => {
        doc => 'GSC Run from LIMS',
        is => 'GSC::Run',
        calculate_from => [qw/ id /],
        calculate => q| GSC::Run->get($id); |,
    },
    ]
};

#< Dump to File System >#
sub dump_to_file_system {
    my $self = shift;

    my $data_dir = $self->create_data_directory_and_link 
        or return;
        
    my $read_cnt = 0;
    my $reads = App::DB::TableRow::Iterator->new(
        class => 'GSC::Sequence::Read',
        params => {
            prep_group_id => $self->run_name,
        },
    );

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

1;

#$HeadURL$
#$Id$
