package Genome::Utility::IO::SeparatedValueWriterTest;

use strict;
use warnings;

use base 'Genome::Utility::TestBase';

use Data::Dumper 'Dumper';
use File::Compare 'compare';
use Test::More;
use Storable 'retrieve';

sub svw {
    return $_[0]->{_object};
}

sub test_class_sub_dir {
    return 'Genome-Utility-IO';
}

sub test_class {
    return 'Genome::Utility::IO::SeparatedValueWriter';
}

sub params_for_test_class {
    my $self = shift;
    return (
        #output => $self->dir.'/myalbums.csv',
        output => $self->tmp_dir.'/albums.csv',
    );
}

sub required_attrs {
    return;
}

sub _headers {
    my $self = shift;

    $self->_set_headers_and_rows unless $self->{_headers};

    return $self->{_headers};
}

sub _rows {
    my $self = shift;

    $self->_set_headers_and_rows unless $self->{_headers};

    return $self->{_rows};
}

sub _albums_csv {
    return $_[0]->dir.'/albums.csv';
}

sub _set_headers_and_rows {
    my $self = shift;

    my $fh = Genome::Utility::FileSystem->open_file_for_reading( $self->_albums_csv )
        or die;
    my $header_line = $fh->getline;
    chomp $header_line;
    $self->{_headers} = [ split(',', $header_line) ];
    while ( my $line = $fh->getline ) {
        chomp $line;
        push @{$self->{_rows}}, [ split(',', $line) ];
    }
    
    return 1;
}

sub test01_write_and_compare : Test(2) {
    my $self = shift;

    my $svw = $self->svw;
    ok($svw->write_one( $self->_headers ), "Wrote headers");
    for my $row ( @{$self->_rows} ) {
        $svw->write_one($row);
    }

    is(compare($svw->get_original_output, $self->_albums_csv, ), 0, 'Compared generated and files');

    return 1;
}

sub test02_write_one_fails : Test(3) {
    my $self = shift;

    my %fails = (
        'undef' => undef,
        'not an aryref' => 'a string',
        'unequal number of elements' => [qw/ too many elements in this ary ref /],
        #'' => [qw//],
    );
    
    my $svw = $self->svw;
    for my $desc ( keys %fails ) {
        ok(!$svw->write_one($fails{$desc}), "Failed as expected, tried to 'write one' w/ $desc");
    }

    return 1;
}

#######################################################################

1;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
