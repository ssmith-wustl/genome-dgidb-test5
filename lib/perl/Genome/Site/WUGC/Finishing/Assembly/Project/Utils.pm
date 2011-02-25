package Finishing::Assembly::Project::Utils;

use strict;
use warnings;

use base 'Finfo::Singleton';

use Data::Dumper;
use Date::Format;
use Filesystem::DiskUtil;
use IO::File;
use IO::String;

sub source_projects_base_directory
{
    return '/gscmnt/815/finishing/projects/tmp-projects';
}

sub projects_base_directory
{
    my ($self, $organism_name) = @_;
    
    $self->fatal_msg("projects_base_directory needs organism name") unless @_ == 2;

    my $projects_dir;
    my $count; # need this?
    do
    {
        $count++;
        $self->fatal_msg("Tried 10 times to get best finishing dir, but could not get one") if $count > 10;
        
        my $dir = Filesystem::DiskUtil->get_best_dir(group => 'finishing');

        $self->fatal_msg("Could not get best dir from disk utility") unless defined $dir;

        my $fin_dir = $dir . '/finishing';
        $projects_dir = $fin_dir . '/projects';

    } until -d $projects_dir;

    $organism_name = lc($organism_name);
    $organism_name =~ s/\s+/_/g;
    
    my $org_dir = $projects_dir . '/' . $organism_name;
    
    mkdir $org_dir unless -d $org_dir;
        
    $self->error_msg("Could not make org dir: $org_dir\:\n$!")
        and return unless -d $org_dir;

    return $org_dir;
}

sub determine_and_create_projects_directory
{
    my ($self, $name, $organism_name) = @_;

    $self->fatal_msg("determine_and_create_projects_directory needs project name and organism name") unless @_ == 3;
    
    my $base_directory = $self->projects_base_directory($organism_name);

    my $directory = sprintf('%s/%s', $base_directory, $name);
    
    unless ( -d $directory )
    {
        mkdir $directory
            or $self->fatal_msg("Can't create directory ($directory) for $name\: $!");
    }

    return $directory;
}

sub contig_lookup_number
{
    my ($self, $ctg, $af_total) = @_;

    $self->error_msg("No contig to lookup")
        and return unless defined $ctg;

    $af_total = $af_total || 300;
    
    my $num = $ctg;
    $num =~ s/contig//ig;
    $num =~ s/\.\d+$//ig;
    
    Finfo::Validate->validate
    (
        attr => "derived contig number ($num) from contig ($ctg)",
        value => $num,
        isa => 'int non_neg',
        obj => $self,
    );
    
    return $num % $af_total;
}

sub validate_projects_hash
{
    my ($self, $projects) = @_;

    Finfo::Validate->validate
    (
        attr => 'projects hash',
        value => $projects,
        ds => 'hashref',
        msg => 'fatal',
        caller_level => 1,
    );

    while ( my ($name, $info) = each %$projects )
    {
        Finfo::Validate->validate
        (
            attr => "project's ($name) info",
            value => $info,
            ds => 'hashref',
            msg => 'fatal',
            caller_level => 1,
        );

        Finfo::Validate->validate
        (
            attr => "project's ($name) db",
            value => $info->{db},
            isa => [ 'in_list', Finishing::Assembly::Factory->available_dbs ],
            msg => 'fatal',
            caller_level => 1,
        );

        if ( $info->{contigs} )
        {
            $self->validate_projects_contigs($name, $info->{contigs});
        }

    }

    return 1
}

sub validate_projects_contigs
{
    my ($self, $project_name, $contigs) = @_;

    Finfo::Validate->validate
    (
        attr => 'project contigs',
        value => $contigs,
        ds => 'aryref',
        msg => 'fatal',
        caller_level => 2,
    );

    foreach my $contig ( @$contigs )
    {
        Finfo::Validate->validate
        (
            attr => "contig for project ($project_name)",
            value => $contig,
            ds => 'hashref',
            msg => 'fatal',
            caller_level => 2,
        );

        my $contig_name = $contig->{name};
        Finfo::Validate->validate
        (
            attr => "contig's original name ($contig_name, project: $project_name)",
            value => $contig_name,
            isa => 'string',
            msg => 'fatal',
        );

        Finfo::Validate->validate
        (
            attr => "contig's db ($contig_name, project: $project_name)",
            value => $contig->{db},
            isa => [ 'in_list', Finishing::Assembly::Factory->available_dbs ],
            msg => 'fatal',
        );

        my $file = $contig->{file};
        if ( $file ) 
        {
            Finfo::Validate->validate
            (
                attr => "contig's file ($file, project: $project_name)",
                value => $contig->{db},
                isa => [ 'in_list', Finishing::Assembly::Factory->available_dbs ],
                msg => 'fatal',
            );
        }

        if ( $contig->{start} or $contig->{stop} )
        {
            Finfo::Validate->validate
            (
                attr => "project's ($project_name) contig ($contig_name) start position",
                value => $contig->{start},
                isa => "int gt 0",
                err_cb => $self,
                msg => 'fatal',
            );

            my $start = $contig->{start} || 1;
            Finfo::Validate->validate
            (
                attr => "project's ($project_name) contig ($contig_name) stop position",
                value => $contig->{stop},
                isa => "int gt $start",
                msg => 'fatal',
            );
        }

    }

    return 1;
}

1;

=pod

=head1 Methods

=head2 tmp_projects_directory

=head2 get_directory_for_tmp_project

=head2 create_directory_for_tmp_project

=head2 get_projects_directory

=head2 create_directory_for_project

=head2 contig_lookup_number

=head2 validate_projects_hash

=head1 See Also

=over

=item B<Finishing::Assembly::Project>

=item B<Finishing::Assembly::Factory>

=item B<Finishing::Assembly::Project::Checkout>

=item B<Finishing::Assembly::Project::XML::Checkout>

=back

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut
#$HeadURL$
#$Id$
