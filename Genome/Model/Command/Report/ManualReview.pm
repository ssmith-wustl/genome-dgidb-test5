package Genome::Model::Command::Report::ManualReview;

use strict;
use warnings;

use above "Genome"; 

use Command;
use Data::Dumper;
use IO::File;

class Genome::Model::Command::Report::ManualReview
{
    is => 'Command',                       
    has => 
    [ 
        map_list => 
        {
            type => 'String',
            is_optional => 0,
            doc => "File of input maps",
        },
        snp_file =>
        {
            type => 'String',
            is_optional => 0,
            doc => "File of variants",    
        },
        output_dir =>
        {
            type => 'String',
            is_optional => 0,
            doc => "Directory to generate Manual Review reports",    
        },
        step =>
        {
            type => 'Integer',
            is_optional => 0,
            doc => "This is a hack since I haven't added job control in the first version",        
        }
    ], 
};

############################################################

sub help_brief {   
    return;
}

sub help_synopsis { 
    return;
}

sub help_detail {
    return <<EOS 
    Creates a manual review directory from a given map list, snp file, and output dir.  The user is required to
    do job monitoring as there is no automated job monitoring in this version.  So, you must rerun this
    command three times, with the appropriate step specified in the step argument.  There are three steps.
    In step 0, intersects of the supplied maps are performed.  In step 1, those intersected map files are 
    merged, and this merge file is written to the output_dir.  In step 2, a tree containing the intersected
    map files and their read lists is created in the output_dir. 
EOS
}

############################################################

sub execute { 
    my $self = shift;

    my $out_dir = $self->output_dir;
    my $step = $self->step;
    my $snps = $self->snp_file;
    my $maplist = $self->map_list;
    
    if(!-e $out_dir) {`mkdir -p $out_dir`;}
    my $fh = IO::File->new($maplist);
    my @lines = <$fh>;
    chomp @lines;
    
    if($step == 0)
    {
        foreach my $line (@lines)
        {
            my $l = basename($line);
            my $f = $line;
            my $o = $f;
            $o =~ s/keep/intersect/;
            print $o,"\n";
            exit if(-e $o);
            system("bsub -q aml -oo $l.log gt maq get-intersect --input=$f --snpfile=$snps --output=$o");
        }    
    }
    elsif($step == 1)
    {
        foreach (@lines) 
        {
            $_ =~ s/keep/intersect/;
        }
        my $maps = join ' ',@lines;       

        system("bsub -q aml -R 'select[type=LINUX64]'-oo mapmerge.log maq mapmerge $out_dir/all.map $maps");
    }
    elsif($step == 2)
    {
        $fh = IO::File->new($snps);    
        foreach my $line (<$fh>)
        {
            chomp $line;
            my ($seq, $pos) = split /\s+/,$line; 
            my $seqpos = $seq.'_'.$pos;
            if(!-e "$out_dir/$seqpos"){`mkdir -p $out_dir/$seqpos`;}
            my $temp_fh = IO::File->new(">$out_dir/$seqpos/annotation.tsv");
            print $temp_fh $line,"\n"; 
        }
        $fh->seek(0,0);

        foreach my $line (<$fh>)
        {   
            chomp $line;
            my ($seq, $pos) = split /\s+/,$line; 
            my $seqpos = $seq.'_'.$pos;
            #system("bsub -q aml -W 50 -oo $seqpos.log gt maq get-intersect --input=$out_dir/all.map --snpfile=$out_dir/$seqpos/annotation.tsv --output=$out_dir/$seqpos/$seqpos.map");
            system("bsub -q aml -W 50 -oo $seqpos.log gt maq get-intersect --input=$out_dir/all.map --snpfile=$out_dir/$seqpos/annotation.tsv --output=$out_dir/$seqpos/$seqpos --justname=2");
        }
    }

    return 1;
}
############################################################


1;

