package Genome::Model::Tools::LiftOver;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::LiftOver {
    is => 'Command',
    has => [
        source_file => {
            is => 'Text',
            doc => 'The file to be translated',
        },
        destination_file => {
            is => 'Text',
            doc => 'Where to output the translated file',
        },
        unmapped_file => {
            is => 'Text',
            doc => 'Where to put the unliftable input',
            is_optional => 1,
        },

    ],
    has_optional => [
        allow_multiple_output_regions => {
            is => 'Boolean',
            doc => 'Whether or not to allow multiple output regions',
            default => '0',
        },
        file_format => {
            is => 'Text',
            doc => 'The format of the source file',
            valid_values => ['bed', 'gff', 'genePred', 'sample', 'pslT'],
            default_value => 'bed',
        },
        input_is_annoformat => {
            is => 'Boolean',
            doc => 'Input is 1-based annotation format',
            default_value => 0,
        },
        chain_file => {
            is => 'Text',
            doc => 'The liftOver "chain" file that maps from the source reference to the destination reference. Needed if the lift-direction param is not specified',
        },
        lift_direction=> {
            is => 'Text',
            doc => 'shorthand for common lift operations one of: [hg19ToHg18,hg18ToHg19]',
        },
    ],
};

sub execute {
    my $self = shift;
    my $source_file = $self->source_file;
    my $lofile;
    my $chain_file;
    my $tempdir;

    if(defined($self->lift_direction)){
        if($self->lift_direction eq "hg19ToHg18"){
            $chain_file = "/gscmnt/sata112/info/medseq/reference_sequences/Homo_sapiens/liftOver_files/hg19_GRCh37_Build-37/hg19ToHg18.over.chain";
        } elsif ($self->lift_direction eq "hg18ToHg19"){
            $chain_file = "/gscmnt/sata112/info/medseq/reference_sequences/Homo_sapiens/liftOver_files/hg18ToHg19.over.chain.gz";
        } else {
            die "unknown lift-direction: " . $self->lift_direction;
        }
    } else {
        if(defined($self->chain_file)){
            $chain_file = $self->chain_file;
        } else {
            die "you must specify either a chain-file or a valid lift-direction"
        }
    }

    #if annotation format is given, convert to a bed, lift it over, and convert back to anno   
    if($self->input_is_annoformat){

        #create temp directory for munging
        $tempdir = Genome::Sys->create_temp_directory();
        unless($tempdir) {
            $self->error_message("Unable to create temporary file $!");
            die;
        }

        open(OUTFILE,">$tempdir/inbed") || die "can't open temp file for writing\n";

        my $inFh = IO::File->new( $source_file ) || die "can't open file\n";
        while( my $line = $inFh->getline )
        {
            chomp($line);
            my @F = split("\t",$line);

            $F[3] =~ s/\*/-/g;
            
            #tabbed format - 1  123  456  A  T
            
            ## liftover doesn't like insertion coordinates (start=stop), so we
            ## add one to the stop to enable a liftover, and remove it on the other side
            ## this is effectively the same as not changing from anno to bed for insertions
            if (($F[3] =~ /0/) || ($F[3] =~ /\-/)){ #indel INS
                #$F[2] = $F[2]-1;
                print OUTFILE join("\t",("chr$F[0]",$F[1],$F[2],join("/",($F[3],$F[4]))));

            } elsif (($F[4] =~ /0/) || ($F[4] =~ /\-/)){ #indel DEL
                $F[1] = $F[1]-1;
                print OUTFILE join("\t",("chr$F[0]",$F[1],$F[2],join("/",($F[3],$F[4]))));

            } else { #SNV
                $F[1] = $F[1]-1;
                print OUTFILE join("\t",("chr$F[0]",$F[1],$F[2],join("/",($F[3],$F[4]))));
            }

            if(@F > 4){
                print OUTFILE "\t" . join("\t",@F[5..$#F])
            }
            print OUTFILE "\n";
        }
        close(OUTFILE);


        $source_file = "$tempdir/inbed";
        $lofile = "$tempdir/outbed";
        ` cp $tempdir/inbed ~/aml/amlx24/paper/`
    }
    

    #do the lifting over
    my $cmd = 'liftOver';
    if($self->file_format ne 'bed') {
        $cmd .= ' -' . $self->file_format;
    }
    if($self->allow_multiple_output_regions) {
        $cmd .= ' -multiple';
    }
    

    if($self->input_is_annoformat){
        $cmd .= join(' ', ('', $source_file, $chain_file, $lofile));
        if($self->unmapped_file) {
            $cmd .= ' ' . $self->unmapped_file;
        }

        Genome::Sys->shellcmd(
            cmd => $cmd,
            input_files => [$source_file, $chain_file],
            output_files => [$lofile],
            );

    } else {
        $cmd .= join(' ', ('', $source_file, $chain_file, $self->destination_file));
        if($self->unmapped_file) {
            $cmd .= ' ' . $self->unmapped_file;
        }

        Genome::Sys->shellcmd(
            cmd => $cmd,
            input_files => [$self->source_file, $chain_file],
            output_files => [$self->destination_file],
            );
    }    

    #convert back to annotation format
    if($self->input_is_annoformat){
        open(OUTFILE,">" . $self->destination_file);
        my $inFh = IO::File->new( $lofile ) || die "can't open file\n";
        while( my $line = $inFh->getline )
        {
            chomp($line);
            my @F = split("\t",$line);

            my @bases = split("/",$F[3]);

            $F[0] =~ s/^chr//g;
            if (($bases[0] =~ /^\-/) ||($bases[0] =~ /^0/)){ #indel INS
                #$F[2] = $F[2]+1; #don't need this because we added one above
                print OUTFILE join("\t",($F[0],$F[1],$F[2],$bases[0],$bases[1]));
            } elsif (($bases[1] =~ /^\-/) ||($bases[1] =~ /^0/)){ #indel DEL
                $F[1] = $F[1]+1;
                print OUTFILE join("\t",($F[0],$F[1],$F[2],$bases[0],$bases[1]));
            } else { #SNV
                $F[1] = $F[1]+1;
                print OUTFILE join("\t",($F[0],$F[1],$F[2],$bases[0],$bases[1]));
            }            
            if(@F > 3){
                print OUTFILE "\t" . join("\t",@F[4..$#F])
            }
            print OUTFILE "\n";
        }
    }    
    
    
    return 1;
}

1;
