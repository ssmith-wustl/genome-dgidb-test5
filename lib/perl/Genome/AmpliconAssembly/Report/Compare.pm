package Genome::AmpliconAssembly::Report::Compare;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::AmpliconAssembly::Report::Compare {
    is => 'Genome::AmpliconAssembly::Report',
};

#< Generator >#
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    my $amplicon_assemblies = $self->amplicon_assemblies;
    my $aa_count = scalar(@$amplicon_assemblies);
    unless ( $aa_count == 2 ) {
        $self->error_message("Need exactly 2 amplicon assemblies to compare. Was given $aa_count.");
        $self->delete;
        return;
    }

    return $self;
}

sub description {
    my $amplicon_assemblies = $_[0]->amplicon_assemblies;
    return sprintf(
        'Camparison Report for Amplicon Assemblies %s and %s',
        $amplicon_assemblies->[0]->description,
        $amplicon_assemblies->[1]->description,
    );
}

sub _add_to_report_xml {
    my $self = shift;

    # Info, Amplicons, Stats, etc
    my %amplicons;
    my @info;
    for my $amplicon_assembly ( @{$self->amplicon_assemblies} ) {
        # amplicons
        my $amplicons = $amplicon_assembly->get_amplicons;
        unless ( $amplicons ) {
            $self->error_message('No amplicons found for amplicon assembly: '.$amplicon_assembly->description);
            return;
        }
        for my $amplicon ( @$amplicons ) {
            push @{$amplicons{$amplicon->name}}, $amplicon;
        }
        
        # stats
        my $stats_report = $self->_generate_stats_report_for_amplicon_assembly($amplicon_assembly)
            or return;
        my $stats_ds = $stats_report->get_dataset('stats');
        unless ( $stats_ds ) {
            $self->error_message("No stats dataset in stats report for amplicon assembly: ".$amplicon_assembly->description);
            return;
        }

        my $attempted = ($stats_ds->get_row_values_for_header('attempted'))[0];
        unless ( $attempted ) {
            $self->error_message('No amplicons were attempted to be assembled for amplicon assembly: '.$amplicon_assembly->description);
            return;
        }

        push @info, [ 
        $attempted, 
        ($stats_ds->get_row_values_for_header('assembled'))[0],
        scalar(@$amplicons),
        map { $amplicon_assembly->$_ } Genome::AmpliconAssembly->attribute_names,
        ];
    }

    # Amplicon Assembly Dataset
    my $aa_dataset = Genome::Report::Dataset->create(
        name => 'amplicon-assemblies',
        row_name => 'amplicon-assembly',
        headers => [
        qw/ assembled attempted amplicons /,
        Genome::AmpliconAssembly->attribute_names,
        ],
        rows => \@info,
    ) or return;
    $self->_add_dataset($aa_dataset)
        or return;
    
    # Compare amplicons
    my %compare = ( # use a basic count or ampicon name?
        amplicon_missing => [],
        classification_matches => [],
        classification_differs => [],
        classification_missing => [],
        classification_none => [],
    );
    for my $amplicon_name ( sort { $a cmp $b } keys %amplicons ) {
        unless ( @{$amplicons{$amplicon_name}} == 2 ) {
            push @{$compare{amplicon_missing}}, $amplicon_name;
            next;
        }
        my ($amplicon1, $amplicon2) = @{$amplicons{$amplicon_name}};

        # classification
        my $classification1 = $amplicon1->get_classification;
        my $classification2 = $amplicon2->get_classification;
        if ( $classification1 and $classification2 ) {
            if ( $classification1->to_string ne $classification2->to_string ) { # differ
                push @{$compare{classification_differs}}, $amplicon1->name;
            }
            else {
                push @{$compare{classification_matches}}, $amplicon1->name;
            }
        }
        elsif ( $classification1 or $classification2 ) { # one is missing
            push @{$compare{classification_missing}}, $amplicon1->name;
        } 
        else { # no classifications
            push @{$compare{classification_none}}, $amplicon1->name;
        }
    }

    # Compare Dataset 
    my @headers = [qw/ assembled attempted classification_differs classification_missing /];
    my $compare_dataset = Genome::Report::Dataset->create(
        name => 'comparisons',
        row_name => 'comparison',
        headers => [ sort { $a cmp $b } keys %compare ],
        rows => [[ map { scalar(@{$compare{$_}}) } sort { $a cmp $b } keys %compare ]],
    ) or return;
    $self->_add_dataset($compare_dataset)
        or return;

    return 1;
}

sub _generate_stats_report_for_amplicon_assembly {
    my ($self, $amplicon_assembly) = @_;

    my $genertor = Genome::AmpliconAssembly::Report::Stats->create(
        amplicon_assemblies => [ $amplicon_assembly ],
    );
    unless ( $genertor ) {
        $self->error_message("Can't create stats report generate for amplicon assembly in directory: ".$amplicon_assembly->directory);
        return;
    }

    my $report = $genertor->generate_report;
    unless ( $report ) {
        $self->error_message("Can't generate stats report generate for amplicon assembly in directory: ".$amplicon_assembly->directory);
        return;
    }

    return $report;
}

1;

=pod

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

