package Genome::Site::WUGC::Finishing::Assembly::Project::XML::Splitter;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;

use Genome::Site::WUGC::Finishing::Assembly::Project::XML;

require File::Basename;

my %xml :name(xml:r)
    :isa('object Genome::Site::WUGC::Finishing::Project::XML');
my %projs_per_file  :name(max_projs_per_file:o) 
    :isa('int pos')
    :default(100) 
    :desc('The max number of projects in each output file (default 10)');
    
sub execute
{
    my $self = shift;

    my ($file_base, $dir) = File::Basename::fileparse($self->xml->file, 'xml');

    my $projects = $self->xml->read_projects;
    my @proj_names = sort { $a cmp $b } keys %$projects;
    my $proj_total = @proj_names;
    my $last_proj_num = $#proj_names;
    $self->info_msg
    (
        "Number of projects in xml is less than or equal to the max number of projects ".
        "per file - no splitting needed"
    )
        and return 1 if $last_proj_num < $self->max_projs_per_file;

    my $file_total = ( $proj_total % $self->max_projs_per_file )
    ? int( $proj_total / $self->max_projs_per_file ) + 1
    : $proj_total / $self->max_projs_per_file;
    $self->info_msg("$proj_total $file_total");

    my @xml_files;
    for ( my $file_num = 1; $file_num <= $file_total; $file_num++ )
    {
        my $start = ( $file_num - 1 ) * $self->max_projs_per_file;
        my $stop = ($file_num * $self->max_projs_per_file) - 1;
        $stop = ( $stop <= $last_proj_num)
        ? $stop
        : $last_proj_num;
        
        my $batch_projs;
        for (my $i = $start; $i <= $stop; $i++)
        {
            $batch_projs->{ $proj_names[$i] } = $projects->{ $proj_names[$i] };
        }
        my $file = sprintf('%s/%s%d.xml', $dir, $file_base, $file_num);
        push @xml_files, $file,
        my $proj_xml = Genome::Site::WUGC::Finishing::Project::XML->new(file => $file);
        $proj_xml->write_projects($batch_projs);
    }

    return \@xml_files;
}

1;

=pod

=head1 Name

Genome::Site::WUGC::Finishing::Project::FileSplitter

=head1 Synopsis

=head1 Usage

=head1 Methods

=head1 See Also

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Finishing/Project/FileSplitter.pm $
#$Id: FileSplitter.pm 29849 2007-11-07 18:58:55Z ebelter $

