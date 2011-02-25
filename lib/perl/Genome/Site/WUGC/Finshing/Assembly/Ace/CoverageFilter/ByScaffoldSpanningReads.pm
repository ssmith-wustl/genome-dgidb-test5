package GSC::IO::Assembly::Ace::CoverageFilter::ByScaffoldSpanningReads;

use strict;
use warnings;

use base qw(GSC::IO::Assembly::Ace::CoverageFilter);

GSC::IO::Assembly::Ace::CoverageFilter::ByScaffoldSpanningReads->mk_accessors
(qw/
    traces
    /);

sub eval_contig
{
    my ($self, $contig) = @_;

    my $name = $contig->name;
    my $length = $contig->sequence->length;

    $self->create_map($contig);

    # Go thru the reads...
    my $traces = $self->traces;
    if ($contig->isa("GSC::IO::Assembly::Contig"))
    {
        foreach my $read ( values %{ $contig->reads } )
        {
            next unless $self->obj_is_ok($read);

            my $read_name = $read->name;

            next if $read_name =~ /^(.+)(_[tg]\d*e?\d*).(\w)\d+$/; # oligo walk

            $read_name =~ /^(.+)\.(\w)\d+$/;
            my $template_name = $1;
            my $ext = $2;

            $traces->{$template_name}->{ext}->{$ext}->{contig_name} = $name;
            $traces->{$template_name}->{ext}->{$ext}->{start} = $read->position + $read->align_clip_start -1;
            $traces->{$template_name}->{ext}->{$ext}->{stop} = $read->position + $read->align_clip_end - 1;
            $traces->{$template_name}->{ext}->{$ext}->{direction} = ($read->complemented)
            ? '<'
            : '>';
        }
    }

    $self->traces($traces);

    return;
}

sub eval_scaffold
{
    my ($self, @scaffolds) = @_;

    $self->configure_traces(@scaffolds);

    my $traces = $self->traces;

    foreach my $template_name (keys %$traces)
    {
        if ($traces->{$template_name}->{in_same_contig}
                and $traces->{$template_name}->{in_correct_orientation})
        {
            my ($contig_name, $start, $stop);
            foreach my $ext (keys %{ $traces->{$template_name}->{ext} })
            {
                $contig_name =  $traces->{$template_name}->{ext}->{$ext}->{contig_name};
                
                my $trace_start = $traces->{$template_name}->{ext}->{$ext}->{start};
                $start = $trace_start if !defined $start || $trace_start < $start;

                my $trace_stop = $traces->{$template_name}->{ext}->{$ext}->{stop};
                $stop = $trace_stop if !defined $stop || $trace_stop > $stop ;
            } 

            $self->edit_map($contig_name, $start, $stop);
        }
        elsif ($traces->{$template_name}->{in_same_scaffold}
                and $traces->{$template_name}->{in_correct_orientation})
        {
            my @contig_names;
            foreach my $ext (keys %{ $traces->{$template_name}->{ext} })
            {
                my $contig_name = $traces->{$template_name}->{ext}->{$ext}->{contig_name};
                
                push @contig_names, $contig_name;
                
                my $direction = $traces->{$template_name}->{ext}->{$ext}->{direction};

                my $start = ($direction eq ">")
                ? $traces->{$template_name}->{ext}->{$ext}->{start}
                : 1;

                my $stop = ($direction eq ">")
                ? $self->map_max($contig_name)
                : $traces->{$template_name}->{ext}->{$ext}->{stop};

                $self->edit_map($contig_name, $start, $stop);
            }
            
            if ($traces->{$template_name}->{ctgs_between})
            {
                foreach my $contig (@{ $traces->{$template_name}->{ctgs_between} })
                {
                    $self->edit_map($contig->name, 1, $self->map_max($contig->name));
                }
            }
        }
        else
        { # These traces have no mate pair, are in different scaffolds or the incorrect orientation
            foreach my $ext (keys %{ $traces->{$template_name}->{ext} })
            {
                my $contig_name =  $traces->{$template_name}->{ext}->{$ext}->{contig_name};
                my $start = $traces->{$template_name}->{ext}->{$ext}->{start};
                my $stop = $traces->{$template_name}->{ext}->{$ext}->{stop};

                $self->edit_map($contig_name, $start, $stop);
            } 
        }
    }

    return;
}

sub configure_traces
{
    my ($self, @scaffolds) = @_;

    my $traces = $self->traces;

    foreach my $template_name (keys %$traces)
    {
        my ($contig1, $contig2) = 
        map { $traces->{$template_name}->{ext}->{$_}->{contig_name} }
        sort keys %{ $traces->{$template_name}->{ext} };

        my ($dir1, $dir2) = 
        map { $traces->{$template_name}->{ext}->{$_}->{direction} }
        sort keys %{ $traces->{$template_name}->{ext} };
        
        if (defined $contig1 and defined $contig2 and $contig1 eq $contig2)
        {     
            $traces->{$template_name}->{in_same_scaffold} = 1;
            $traces->{$template_name}->{in_same_contig} = 1;
            if (($dir1 eq '>' and $dir2 eq '<')
                    or ($dir2 eq '>' and $dir1 eq '<'))
            {
                $traces->{$template_name}->{in_correct_orientation} = 1;
            }
            else
            {
                $traces->{$template_name}->{in_correct_orientation} = 0;
            }
            next;
        }
        else
        {
            $traces->{$template_name}->{in_same_contig} = 0;
            $traces->{$template_name}->{in_same_scaffold} = 0;
        }

        foreach my $scaffold (@scaffolds)
        {
            my $pos1 = $scaffold->ctg_position($contig1);
            next unless $pos1;
            my $pos2 = $scaffold->ctg_position($contig2);
            next unless $pos2;

            my @ctgs_between = $scaffold->ctgs_between($contig1, $contig2);

            $traces->{$template_name}->{in_same_scaffold} = 1;
            $traces->{$template_name}->{ctgs_between} = \@ctgs_between if @ctgs_between;

            my $ori1 = $scaffold->ctg_orientation($contig1);
            my $ori2 = $scaffold->ctg_orientation($contig2);

            if (($ori1 eq '+' and $ori2 eq '+')
                    or ($ori1 eq '-' and $ori2 eq '-'))
            {
                if (($dir1 eq '>' and $dir2 eq '<')
                        or ($dir2 eq '>' and $dir1 eq '<'))
                {
                    $traces->{$template_name}->{in_correct_orientation} = 1;
                }
                else
                {
                    $traces->{$template_name}->{in_correct_orientation} = 0;
                }
            }
            elsif (($ori1 eq '+' and $ori2 eq '-')
                    or ($ori1 eq '-' and $ori2 eq '+'))
            {
                if (($dir1 eq '>' and $dir2 eq '>')
                        or ($dir2 eq '<' and $dir1 eq '<'))
                {
                    $traces->{$template_name}->{in_correct_orientation} = 1;
                }
                else
                {
                    $traces->{$template_name}->{in_correct_orientation} = 0;
                }
            }
            else
            {
                $traces->{$template_name}->{in_correct_orientation} = 0;
            }

            last;
        }
    }

    $self->traces($traces);

    return;
}

sub obj_is_ok
{
    my ($self, $obj) = @_;

    return grep $obj->name =~ /$_/, $self->patterns
}

=pod

=head1 Name

GSC::IO::Assembly::Ace::CoverageFilter::ByScaffoldSpanningReads

> Creates a map of each given contig representing the areas covered by
   reads that span a scaffold.

   ** Inherits from GSC::IO::Assembly::Ace::CoverageFilter **

=head1 Synopsis

my $cf = GSC::IO::Assembly::Ace:CoverageFilter::ByScaffoldSpanningReads->new
 (\@patterns);

foreach my $contig (@contigs)
{
 $cf->eval_contig($contig);
}

$cf->eval_scaffold(@scaffolds); # Required!

my @objs = $cf->get_all_objects;

=head1 Methods

=head2 eval_contig($contig)

 Evaluates the reads in a GSC::IO::Assembly::Contig and creates a contig map.
 
=head2 eval_scaffold(@scaffold)

 Evaluates the reads from the contigs taking in considerationthe scaffold
 objects (GSC::IO::Scaffold::Scaffold) and creates a map foreach contig.
 
=head1 See Also

Base class -> GSC::IO::Assembly::CoverageFilter
 
=head1 Author

Eddie Belter <ebelter@watson.wustl.edu>

=cut

1;

