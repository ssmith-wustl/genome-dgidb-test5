package Genome::Model::Tools::Velvet::ToConsed;

use strict;
use warnings;

use Genome;
use Cwd 'abs_path';
use File::Basename;


class Genome::Model::Tools::Velvet::ToConsed {
    is           => 'Command',
    has          => [
        fastq_file  => {
            is      => 'String',
            doc     => 'Input fastq file to start the velvet assembly',
        },
        afg_file    => {
            is      => 'String', 
            doc     => 'input velvet_asm.afg file path(s)',
        },
    ],
    has_optional => [
        out_acefile => {
            is      => 'String', 
            doc     => 'name for output acefile, default is ./velvet_asm.ace',
            default => 'velvet_asm.ace',
        },
        chunk_size  => {
            is      => 'Integer',
            doc     => 'number of fastq sequences each chunk',
            default => 10000,
        },
	fast_mode   => {
	    is      => 'Boolean',
	    doc     => 'Allow by-passing of bio perl usage for speed for fastq files with less than 1,000,000 reads',
	    default => 0,
	},
	no_scf      => {
	    is      => 'Boolean',
	    doc     => 'Do not make chromat files',
	    default => 0,
	},
    ],
};

sub help_brief {
    'This tool converts velvet assembly to acefile, then convert input read fastq file into phdball and scf files',
}


sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;
    my $time = localtime;

    my $acefile  = $self->out_acefile;
    my $edit_dir = dirname(abs_path($acefile));

    unless ($edit_dir =~ /edit_dir/) {
	$self->error_message("Ace file $acefile has to be in edit_dir");
	return;
    }
    my $base_dir = dirname $edit_dir;
    
    my @steps = qw(Velvet_to_Ace Fastq_to_phdball_scf);

    my $to_ace  = Genome::Model::Tools::Velvet::ToAce->create(
	afg_file    => $self->afg_file,
	out_acefile => $acefile,
	time        => $time,
    );
    my $rv = $to_ace->execute;
    return unless $self->_check_rv($steps[0], $rv);

    my %to_phdscf_params = (
	fastq_file => $self->fastq_file,
        ball_file  => $edit_dir.'/phd.ball',
        base_fix   => 1,
        time       => $time,
        chunk_size => $self->chunk_size,
	fast_mode  => $self->fast_mode,
	);

    unless ( $self->no_scf ) {
	$to_phdscf_params{scf_dir} = $base_dir.'/chromat_dir';
    }

    my $to_phdscf = Genome::Model::Tools::Fastq::ToPhdballScf::Chunk->create( %to_phdscf_params );
    $rv = $to_phdscf->execute;
    return unless $self->_check_rv($steps[1], $rv);

    return 1;
}


sub _check_rv {
    my ($self, $step, $rv) = @_;
    
    if ($rv) {
        $self->status_message("$step done");
    }
    else {
        $self->error_message("$step failed");
    }
    return $rv;
}

1;

