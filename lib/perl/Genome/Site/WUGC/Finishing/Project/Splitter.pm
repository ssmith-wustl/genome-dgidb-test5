package Genome::Site::WUGC::Finishing::Project::Splitter;

# TODO this needs to be tweaked a bit, the projs are greater than the
# target size by the difference of the overlap

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;

# req
my %project_namer :name(project_namer:r) 
    :type(inherits_from) 
    :options([ 'Genome::Site::WUGC::Finishing::Project::Namer' ]);
my %xml :name(xml:r)
    :type(inherits_from)
    :options([qw/ Genome::Site::WUGC::Finishing::Project::XML /]);
#opt
my %inc_proj_name_in_ctg_name :name(include_proj_name_in_ctg_name:o) 
    :type(defined) 
    :default(0)
    :clo('inc-proj-in-ctg')
    :desc('This will include the project name in each of the project\'s contig names');
my %target_size :name(target_size:o)    
    :type(integer_gte)
    :default(1000000)
    :options([ 5000 ])
    :clo('ts=i')
    :desc('Target bp size of projects');
my %no_split :name(no_split:o) 
    :type(defined)
    :default(0)
    :clo('ns')
    :desc('No Split - don\'t split contigs.  Can\'t use --ov and --gr (flag)');
# TODO add clopts...
my %overlap :name(overlap:o) 
    :type(integer_between)
    :default(2000)
    :options([ 0, 10000 ]);
my %gap_range :name(gap_range:o) 
    :type(integer_between)
    :default(0)
    :options([ 0, 10000 ]);
my %min_size :name(min_size:o)
    :type(non_negative_integer)
    :default(0);
# priv
my %saved_ctg :name(_saved_ctg:p);
my %saved_start :name(_saved_start:p) :type(pos_int);
my %saved_end :name(_saved_end:p) :type(pos_int);
my %queued_ctg :name(_queued_ctg:p);

sub execute
{
    my $self = shift;

    my $projects;
    my $num = 0;
    while (1)
    {
        my ($contig, $u_start, $u_end, $u_length) = $self->_next_contig
            or last;

        # If new project, set name and size
        unless ( defined $projects->[$num]->{name} )
        {
            $projects->[$num]->{name} = $self->project_namer->next_name
                or return;
            $projects->[$num]->{size} = 0;
            $self->_change_base_name_and_reset_ctg_namer($projects->[$num]->{name})
                or return;
        }

        if ( $self->_should_complete_project($projects->[$num]->{size}, $u_length, $u_end) )
        {
            if ( $self->no_split )
            {
                $self->_add_contig_to_project
                (
                    $projects->[$num], $self->_get_contigs_name($contig), $u_start, $u_end
                )
                    or return;
                $num++;
                next;
            }
            
            my $split_start = $u_start;
            my $split_end = $self->target_size - $projects->[$num]->{size} + $split_start - 1;

            # Adjust the split_end if the split_end would fall w/in
            # the gap_range of the start or end of the contig
            if ($split_end < $self->gap_range)
            {
                $split_end = $self->gap_range;
            }
            elsif ($split_end >= $u_length - $self->gap_range)
            {
                $split_end = $u_length - $self->gap_range;
            }

            # Save The contig, start and end for the next pass
            my $saved_start = ($split_end - $self->overlap + 1 > 1)
            ? $split_end - $self->overlap + 1
            : 1;
            
            # Add the overlap to the split end
            $split_end = ($split_end + $self->overlap < $u_end)
            ? $split_end + $self->overlap
            : $u_end;

            $self->_save_contig($contig, $saved_start, $u_end)
                or return;
            $self->_add_contig_to_project
            (
                $projects->[$num], $self->_get_contigs_name($contig), $split_start, $split_end
            )
                or return;

            # Increment to the next project
            $num++;
        }
        else
        {
            $self->_add_contig_to_project
            (
                $projects->[$num], $self->_get_contigs_name($contig), $u_start, $u_end
            )
                or return;
        }
    }

    $self->error_msg("No projects made")
        and return unless @$projects;
    
    $projects->[0]->{comment} = 'first project';
    $projects->[-1]->{comment} = 'last project';
    
    $self->_writer->write_many($projects)
        or return;
    
    return $projects;
}

sub _next_contig : RESTRICTED
{
    my $self = shift;

    if ( $self->_saved_contig )
    {
        return $self->_get_saved_contig;
    }
    elsif ( $self->_queued_contig )
    {
        return $self->_get_queued_contig;
    }

    return;
}

sub _get_queued_contig : RESTRICTED
{
    my $self = shift;

    my $contig = $self->_queued_contig;
    
    $self->_queue_contig;
    
    if ($contig)
    {
        my $start = 1;
        my $end = $self->_get_contigs_unpadded_end($contig);
        $self->error_msg("Could not get start for contig: " . $self->_get_contigs_name($contig))
            and return unless $start;
        $self->error_msg("Could not get end for contig: " . $self->_get_contigs_name($contig))
            and return unless $end;
        return ($contig, $start, $end, $end - $start + 1);
    }
    
    return;
}

sub _get_saved_contig : RESTRICTED
{
    my $self = shift;

    my $contig = $self->_saved_contig;
    my $start = $self->_saved_start;
    my $end = $self->_saved_end;

    $self->undef_attribute('_saved_contig');
    $self->undef_attribute('_saved_start');
    $self->undef_attribute('_saved_end');

    return ($contig, $start, $end, $end - $start + 1);
}

sub _save_contig : RESTRICTED
{
    my ($self, $contig, $start, $end) = @_;

    $self->_saved_contig($contig);
    $self->_saved_start($start);
    $self->_saved_end($end);

    return 1;
}

sub _should_complete_project : RESTRICTED
{
    my ($self, $size, $u_length, $u_end) = @_;

    if ($u_length + $size > $self->target_size and $u_length > $self->min_size)
    {
        return 1;
    }

    return;
}

sub _change_base_name_and_reset_ctg_namer : RESTRICTED
{
    my ($self, $proj_name) = @_;

    my $base_name;
    if ( $self->include_proj_name_in_ctg_name )
    {
        $self->error_msg("No project name to include in contig names")
            and return unless $proj_name;
        $base_name = "$proj_name.Contig";
    }
    else
    {
        $base_name = 'Contig';
    }

    unless ( $self->_ctg_namer )
    {
        $self->_ctg_namer
        (
            Project::Namer->new(base_name => $base_name)
        );
    }
    else
    {
        $self->_ctg_namer->change_base_name_and_reset($base_name);
    }

    return 1;
}

sub _add_contig_to_project : PRIVATE
{
    my ($self, $project, $old_name, $start, $stop) = @_;


    $self->error_msg("Missing param to add contig to project:\n" . Dumper(\@_))
        and return unless @_ == 5;
    
    $self->info_msg
    (
        sprintf
        (
            'Adding contig %s (%d to %d) to %s',
            $old_name, $start, $stop, $project->{name}
        )            
    );

    $project->{contigs}->{ $self->_ctg_namer->next_name } = 
    {
        aceinfo => join('=', $self->acefile, $old_name),
        start => $start,
        stop => $stop,
    };

    $project->{size} += $stop - $start + 1;

    return 1;
}

1;

