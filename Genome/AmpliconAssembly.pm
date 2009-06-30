package Genome::AmpliconAssembly;

use strict;
use warnings;

use Genome;

require Genome::Consed::Directory;
require Genome::AmpliconAssembly::Amplicon;

class Genome::AmpliconAssembly {
    is => 'UR::Object',
    has => [ 
    __PACKAGE__->attributes,
    ],
};

sub attributes {
    return (
    directory => {
        is => 'Text',
        doc => 'Base directory',
    },
    sequencing_center => {
        is => 'Text',
        is_optional => 1,
        default_value => __PACKAGE__->default_sequencing_center,
        doc => 'Sequencing Center that the amplicons were sequenced.  Currently supported centers: '.__PACKAGE__->valid_sequencing_centers,
    },
);
}

sub helpful_methods {
    return (qw/ 
        chromat_dir phd_dir edit_dir
        consed_directory create_directory_structure
        get_amplicons 
        amplicon_fasta_types amplicon_bioseq_method_for_type
        fasta_file_for_type qual_file_for_type
        assembly_fasta reads_fasta processed_fasta 
        /);
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( Genome::Utility::FileSystem->validate_existing_directory( $self->directory ) ) {
        $self->delete;
        return;
    }

    my $sequencing_center = $self->sequencing_center;
    unless ( grep { $_ eq $sequencing_center } valid_sequencing_centers() ) {
        $self->error_message(
            "Invalid sequencing center: $sequencing_center.  Valid centers: ".join(', ',valid_sequencing_centers())
        );
        $self->delete;
        return;
    }

    $self->create_directory_structure
        or return;

    return $self;
}

#< Sequencing Centers >#
sub valid_sequencing_centers {
    return (qw/ gsc broad /);
}

sub default_sequencing_center {
    return (valid_sequencing_centers)[0];
}

#< DIRS >#
sub consed_directory {
    my $self = shift;

    unless ( $self->{_consed_directory} ) {
        $self->{_consed_directory} = Genome::Consed::Directory->create(directory => $self->directory);
    }

    return $self->{_consed_directory};
}

sub create_directory_structure {
    my $self = shift;

    $self->consed_directory->create_extended_directory_structure
        or return;

    return 1;
}

sub edit_dir {
    return $_[0]->consed_directory->edit_dir;
}
    
sub phd_dir {
    return $_[0]->consed_directory->phd_dir;
}
    
sub chromat_dir {
    return $_[0]->consed_directory->chromat_dir;
}

sub fasta_dir {
    return $_[0]->consed_directory->fasta_dir;
}

#< FASTA >#
my %_fastas_and_amplicon_bioseq_methods = (
    reads => 'get_bioseqs_for_raw_reads',
    processed => 'get_bioseqs_for_processed_reads',
    assembly => 'get_assembly_bioseq',
    oriented => 'get_oriented_bioseq',
);

sub amplicon_fasta_types {
    return keys %_fastas_and_amplicon_bioseq_methods;
}

sub amplicon_bioseq_method_for_type {
    return $_fastas_and_amplicon_bioseq_methods{$_[1]};
}

sub fasta_file_for_type {
    my ($self, $type) = @_;

    return sprintf(
        '%s/%s.fasta',
        $self->fasta_dir,
        $type,
    );
}

sub qual_file_for_type {
    return $_[0]->fasta_file_for_type($_[1]).'.qual';
}

#< Amplicons >#
sub get_amplicons {
    my $self = shift;

    my $method = sprintf('_determine_amplicons_in_chromat_dir_%s', $self->sequencing_center);
    my $amplicons = $self->$method;
    unless ( $amplicons and %$amplicons ) {
        $self->error_message(
            sprintf('No amplicons found in chromat_dir of directory (%s)', $self->directory) 
        );
        return;
    }

    my @amplicons;
    my $edit_dir = $self->edit_dir;
    for my $name ( keys %$amplicons ) {
        push @amplicons, Genome::AmpliconAssembly::Amplicon->create(
            name => $name,
            reads => $amplicons->{$name},
            directory => $edit_dir,
        );
    }

    return \@amplicons;
}

sub _determine_amplicons_in_chromat_dir_gsc {
    my $self = shift;

    my $dh = Genome::Utility::FileSystem->open_directory( $self->chromat_dir )
        or return;

    my %amplicons;
    while ( my $scf = $dh->read ) {
        next if $scf =~ m#^\.#;
        $scf =~ s#\.gz##;
        $scf =~ /^(.+)\.[bg]\d+$/
            or next;
        push @{$amplicons{$1}}, $scf;
    }
    $dh->close;

    return \%amplicons;
}

sub _determine_amplicons_in_chromat_dir_broad {
    my $self = shift;

    my $dh = Genome::Utility::FileSystem->open_directory( $self->chromat_dir )
        or return;

    my %amplicons;
    while ( my $scf = $dh->read ) {
        next if $scf =~ m#^\.#;
        $scf =~ s#\.gz$##;
        my $amplicon = $scf;
        $amplicon =~ s#\.T\d+$##;
        $amplicon =~ s#[FR](\w\d\d?)$#\_$1#; # or next;

        push @{$amplicons{$amplicon}}, $scf;
    }
    
    return  \%amplicons;
}

1;

=pod

=head1 Name

Genome::AmpliconAssembly

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 valid_sequencing_centers

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 default_sequencing_center

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 consed_directory

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 create_directory_structure

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 edit_dir

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 phd_dir

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 chromat_dir

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 fasta_dir

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 amplicon_fasta_types

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 amplicon_bioseq_method_for_type

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 fasta_file_for_type

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 qual_file_for_type

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 get_amplicons

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 contamination_dir

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 contamination_reads_dir

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 amplicon_fasta_file_for_contamination_screening

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 create_contamination_dir

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 create_amplicon_fasta_files_for_contamination_screening

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head2 read_is_contaminated

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2009 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$

