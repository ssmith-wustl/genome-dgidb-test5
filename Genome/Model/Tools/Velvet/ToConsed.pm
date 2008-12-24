package Genome::Model::Tools::Velvet::ToConsed;

use strict;
use warnings;

use Genome;
use IO::File;
use Cwd 'abs_path';
use File::Basename;

use Bio::SeqIO;
use GSC::IO::Assembly::Ace::Reader;
use Genome::Model::Tools::Velvet::ToAce;
use Genome::Model::Tools::Velvet::ToReadFasta;
use Genome::Model::Tools::Fasta::To::Scf;
use Genome::Model::Tools::Fasta::To::Phd;


class Genome::Model::Tools::Velvet::ToConsed {
    is           => 'Command',
    has_many     => [
        afg_files   => {
            is      => 'String', 
            doc     => 'input velvet_asm.afg file path(s)',
        }
    ],
    has_optional => [
        out_acefile => {
            is      => 'String', 
            doc     => 'name for output acefile, default is ./velvet_asm.ace',
            default => 'velvet_asm.ace',
        },
    ],
};
        

sub help_brief {
    'This tool combines workflow: ToAce, ToReadFasta, Fasta::To::Scf, Fasta::To::Phd',
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
    
    my @steps = qw(Velvet_to_Ace Ace_to_ReadFasta Fasta_to_Phd Fasta_to_Scf);
    
    my $to_ace  = Genome::Model::Tools::Velvet::ToAce->create(
        afg_files   => [$self->afg_files],
        out_acefile => $acefile,
        time        => $time,
    );
    my $rv = $to_ace->execute;

    return unless $self->_check_rv($steps[0], $rv);
     
    my $fa_file = $edit_dir.'/reads.fasta';
    
    my $to_fa = Genome::Model::Tools::Velvet::ToReadFasta->create(
        ace_file => $acefile,
        out_file => $fa_file,
    );
    $rv = $to_fa->execute;
    
    return unless $self->_check_rv($steps[1], $rv);
    
    my $fa_to_phd = Genome::Model::Tools::Fasta::To::Phd->create(
        fasta_file => $fa_file,
        dir        => $base_dir.'/phd_dir',
        time       => $time,
    );
    #probably need check phd/scf list for existing ones
    $rv = $fa_to_phd->execute;
    
    return unless $self->_check_rv($steps[2], $rv);
    
    my $to_scf = Genome::Model::Tools::Fasta::To::Scf->create(
        fasta_file => $fa_file,
        dir        => $base_dir.'/chromat_dir',
    );
    $rv = $to_scf->execute;

    return unless $self->_check_rv($steps[3], $rv);
    
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

