package Genome::InstrumentData::Sanger;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Sanger {
    is  => 'Genome::InstrumentData',
};

sub _resolve_data_path {
    my $self = shift;

    return sprintf('%s/%s', $self->_sample_data_base_path, $self->run_name);
}

sub _dump_data_to_filesystem {
    my $self = shift;

    my $read_cnt = 0;
    my $reads = App::DB::TableRow::Iterator->new(
        class => 'GSC::Sequence::Read',
        params => {
            prep_group_id => $self->run_name,
        },
    );

    my $data_dir = $self->_resolve_data_path;
    while ( my $read = $reads->next ) {
        $read_cnt++;
        my $scf_name = $read->default_file_name('scf');
        my $scf_file = sprintf('%s/%s.gz', $data_dir, $scf_name);
        unless ( -s $scf_file ) {
            unlink $scf_file if -e $scf_file;
            my $scf_fh = IO::File->new($scf_file, 'w');
            unless ( $scf_fh ) {
                $self->error_message("Can't open scf ($scf_file)\n$!");
                return;
            }
            $scf_fh->print( Compress::Zlib::memGzip($read->scf_content) );
            $scf_fh->close;
            $self->error_message("No scf content for $scf_name") 
                and next unless -s $scf_file;
        }
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
