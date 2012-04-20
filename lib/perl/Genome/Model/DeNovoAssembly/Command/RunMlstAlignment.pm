package Genome::Model::DeNovoAssembly::Command::RunMlstAlignment;

use strict;
use warnings;

use Genome;

class Genome::Model::DeNovoAssembly::Command::RunMlstAlignment {
    is => 'Genome::Command::Base',
    has => [
        sample_name => {
            is => 'Text',
            doc => 'Instrument data sample name to run alignment on latest succeeded de-novo velvet build',
            is_optional => 1,
        },
        query_build_id => {
            is => 'Number',
            doc => 'DeNovo assembly build id',
            is_optional => 1,
        },
        reference_build_id => {
            is => 'Number',
            doc => 'Imported reference sequence build id',
        },
        output_dir => {
            is => 'Text',
            doc => 'Directory to output alignments to',
        },
        show_coords_params => {
            is => 'Text',
            doc => 'Params to use to run show-coords, eg \'-rclT -I 0.5 -M 500\'',
            is_optional => 1,
        },
    ],
};

sub help_brief {
    'Command to run Nucmer MLST alignments on de-novo assemblies'
}

sub help_detail {
    return <<"EOS"
genome model de-novo-assembly run-mlst-alignment --query_build-id --reference-build-id --show-coords command \'-rclT -M 500\' --output-dir
genome model de-novo-assembly run-mlst-alignment --sample-name --reference-build-id --output-dir
EOS
}

sub execute {
    my $self = shift;

    # derive query denovo build
    my $query_build;
    if ( not $query_build = $self->_resolve_query_build ) {
        $self->error_message('Failed to resolve query build');
        return;
    }

    # ref seq build
    my $reference_build;
    if ( not $reference_build = $self->_resolve_reference_build ) {
        $self->error_message('Failed to get resolve reference build');
        return;
    }

    # output dir
    if ( not -d $self->output_dir ) {
        $self->error_message('Failed to find output directory: '.$self->output_dir);
        return;
    }
    
    # validate show-coords params
    my %show_coords_params;
    if ( $self->show_coords_params ) {
        if ( not %show_coords_params = $self->_validate_show_coords_params ) {
            $self->error_message('Failed to validate show-coords params');
            return;
        }
    }

    # run nucmer
    my $nucmer_prefix = $self->output_dir.'/'.$query_build->subject_name;;
    unlink $nucmer_prefix.'.delta'; # nucmer output file .. won't get over-written if exists
    my $reference_fasta = $reference_build->full_consensus_path('fa');
    my $nucmer = Genome::Model::Tools::Mummer::Nucmer->create(
        prefix => $nucmer_prefix,
        query => $query_build->contigs_bases_file,
        reference => $reference_fasta,
    );
    if ( not $nucmer ) {
        $self->error_message('Failed to create nucmer');
        return;
    }
    if ( not $nucmer->execute ) {
        $self->error_message('Failed to execute nucmer');
        return;
    }

    # run show-coords
    my $show_coords = Genome::Model::Tools::Mummer::ShowCoords->create(
        input_delta_file => $nucmer_prefix.'.delta',
        output_file => $nucmer_prefix.'.alignments.txt',
        %show_coords_params,
    );
    if ( not $show_coords ) {
        $self->error_message('Failed to create show-coords tool');
        return;
    }
    if ( not $show_coords->execute ) {
        $self->error_message('Failed to execute show-coords');
        return;
    }

    return 1;
}

sub _resolve_query_build {
    my $self = shift;

    if ( not $self->sample_name and not $self->query_build_id ) {
        $self->error_message('Supply sample_name or query_build_id for get query sequence');
        return;
    }

    my $expected_subclass_name = 'Genome::Model::Build::DeNovoAssembly::Velvet';

    my $build;
    if ( $self->query_build_id ) {
        $build = Genome::Model::Build->get( $self->query_build_id );
        if ( not $build ) {
            $self->error_message('Failed to get build for id: '.$self->query_build_id);
            return;
        }
        if ( not $build->status eq 'Succeeded' ) {
            $self->error_message('Build '.$self->query_build_id.' has status of '.$build->status.', choose one that has succeeded');
            return;
        }
        if ( not $build->subclass_name eq $expected_subclass_name ) {
            $self->error_message("Expected a $expected_subclass_name build ".$self->query_build_id.' but got '.$build->subclass_name);
            return;
        }
    }
    elsif ( $self->sample_name ) {
        my $sample = Genome::Sample->get( name => $self->sample_name );
        if ( not $sample ) {
            $self->error_message('Failed to get genome sample for name: '.$self->sample_name);
            return;
        }
        my @builds = Genome::Model::Build->get(
            subject_id    => $sample->id,
            subclass_name => $expected_subclass_name,
            status        => 'Succeeded'
        );
        if ( not @builds ) {
            $self->status_message('Found NO succeeded de-novo velvet builds for sample: '.$self->sample_name);
            return;
        }

        # get the latest build
        $build = $builds[-1];
    }

    if ( $self->sample_name and $self->query_build_id ) {
        if ( not $build->subject_name eq $self->sample_name ) {
            $self->error_message('sample_name supplied, '.$self->sample_name.', does not match build subject name, '.$build->subject_name);
            return;
        }
    }

    $self->status_message('Using build_id: '.$build->id.' for query build');

    return $build;
}

sub _resolve_reference_build {
    my $self = shift;

    my $build = Genome::Model::Build->get( $self->reference_build_id );
    if ( not $build ) {
        $self->error_message('Failed to get reference build for id: '.$self->reference_build_id);
        return;
    }

    if ( not $build->subclass_name =~ /ImportedReferenceSequence/ ) {
        $self->error_message('Expected ImportedReferenceSequence build but got: '.$build->subclass_name);
        return;
    }

    if ( not -s $build->full_consensus_path('fa') ) {
        $self->error_message('Failed to get reference sequence build or file is zero size: '.$build->full_consensus_path('fa'));
        return;
    }

    return $build;
}

sub _validate_show_coords_params {
    my $self = shift;
    my %p;
    my @ps = ( split /-/, $self->show_coords_params );
    shift @ps if $ps[0] eq ''; # from split
    for my $param ( @ps ) {
        $param =~ s/\s+$//;
        $param =~ s/^\s+//;
        if ( $param =~ /\d+/ ) {
            # eg -I0.5, -I 0.5 or -I=0.5 or -M 500
            my ( $name, $value ) = $param =~ /^(\S)\s?\=?(\d+\.\d+|\d+)$/;
            if ( not $name and not $value ) {
                $self->status_message("Failed to get valid name and value from param: $param");
                return;
            }
            $p{$name} = $value;
        } else {
            # boleans eg -rlcT
            my @ps = split( '', $param );
            for my $name ( @ps ) {
                $p{$name} = 1;
            }
        }
    }

    if ( not $self->validate_param_name(%p) ) {
        $self->error_message('Failed to validate show-coords param');
        return;
    }

    return %p;
}

sub validate_param_name {
    my ( $self, %params ) = @_;

    my $class = 'Genome::Model::Tools::Mummer::ShowCoords';
    my $class_meta = $class->get_class_object; # dies if not
    if ( not $class_meta ) {
        $self->error_message("No genome class found for $class");
        return;
    }
 
    foreach my $name ( keys %params ) {
        my $property = $class_meta->property_meta_for_name($name);
        if ( not $property ) {
            $self->error_message("Invalid param, $name, specified for $class");
            return;
        }
        # TODO - validate values ?
    } 

    return 1;
}

1;
