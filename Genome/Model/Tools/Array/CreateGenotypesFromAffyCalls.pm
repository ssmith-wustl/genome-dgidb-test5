package Genome::Model::Tools::Array::CreateGenotypesFromAffyCalls;

use strict;
use warnings;

use Genome;
use Command;
use Text::CSV_XS;
use Sort::Naturally qw( nsort );

class Genome::Model::Tools::Array::CreateGenotypesFromAffyCalls {
    is => 'Command',
    has => [
    annotation_file =>
    {
        type => 'String',
        is_optional => 0,
        doc => "Annotation file for the array information being converted",
    },
    call_file => 
    {
        type => 'String',
        is_optional => 0,
        doc => "File of calls describing which allele of the probe was detected",
    },
    output_directory =>
    {
        type => 'String',
        is_optional => 0,
        doc => "Directory to place individual files for each header in the file",
    },

    ]
};


sub execute {
    my $self=shift;

    #TODO Some basic file checks

    my $call_href = $self->create_call_file_hash;

    #Store the header information for creating filenames later
    my @filehandles = @{$call_href->{PS_ID}};

    $call_href = $self->convert_to_genotype($call_href);

    #Convert each call into a genotype and write to a new file by chromosome and position
    #create file handles to write out each sample
    my $out_dir = $self->output_directory;
    for my $file (@filehandles) {
        my $filehandle = new IO::File "$out_dir/$file.genotype", "w";
        unless(defined($filehandle)) {
            $self->error_message("Couldn't open filehandle for file: $file");
            return;
        }   
        $file = $filehandle;
    }

    for my $chromosome (nsort keys %$call_href) {
        for my $position (sort {$a <=> $b} keys %{$call_href->{$chromosome}}) {
            my $i;
            for($i = 0; $i < scalar(@{$call_href->{$chromosome}{$position}}); $i++) {
                print {$filehandles[$i]} "$chromosome\t$position\t",${$call_href->{$chromosome}{$position}}[$i],"\n";
            }
        }
    }

    map { $_->close; } @filehandles;
    
    
    return 1;
}

sub create_call_file_hash {
    my $self = shift;
    my $file = $self->call_file;
    my %call_hash;

    my $fh = new IO::File "$file", "r";
    unless(defined($fh)) {
        return 0;
    }

    my $expected_calls = undef;

    while(my $line = $fh->getline) {

        my ($PS_ID, $dbSNP_rs_id, $chromosome, $phys_pos, @calls) = split /\s+/, $line;

        if(defined($expected_calls) && $expected_calls != scalar(@calls)) {
            $self->error_message("Unexpected number of calls");
            $self->return;
        }
        else {
            $expected_calls = scalar(@calls);
        }
        
        $call_hash{$PS_ID} = \@calls; 
    }
    return \%call_hash;
}

sub convert_to_genotype {
    my ($self, $calls) = @_;

    my $csv = new Text::CSV_XS;
    my $file = $self->annotation_file;
    my $afh = new IO::File "$file","r";

    my %new_calls;

    while(my $line = <$afh>) {
        chomp ($line);    

        #Skip comment lines
        next if($line =~ /^ \# (.*) $/xi);

        # Header
        #
        # "Probe Set ID","Affy SNP ID","dbSNP RS ID","Chromosome","Physical
        # Position","Strand","ChrX pseudo-autosomal region
        # 1","Cytoband","Flank","Allele A","Allele B","Associated Gene","Genetic
        # Map","Microsatellite","Fragment Enzyme Length Start Stop","Allele
        # Frequencies","Heterozygous Allele Frequencies","Number of
        # individuals/Number of chromosomes","In Hapmap","Strand Versus dbSNP","Copy
        # Number Variation","Probe Count","ChrX pseudo-autosomal region 2","In Final
        # List","Minor Allele","Minor Allele Frequency"

        $csv->parse($line);

        my
        ($snp_id,$as_id,$dbsnp,$chr,$phys,$strand,$pseudo,$cyto,$flank,$alleleA,$alleleB,$gene,$field)
        = $csv->fields();

        #next if($snp_id !~ /^$snprange$/xi);
        next if $phys =~ /\-/; #exclude ambiguous sites

        if(exists($calls->{$snp_id})) {
            foreach my $call (@{$calls->{$snp_id}}) {

                if($call eq 'AA') {
                    $call = $alleleA x 2;
                }
                elsif($call eq 'AB') {
                    $call = $alleleA . $alleleB;
                }
                elsif($call eq 'BB') {
                    $call = $alleleB x 2;
                }
                elsif($call eq 'NC') {
                    $call = '--';
                }
                else {
                    warn "Unrecognized genotype call $call. Skipping...\n";
                    next;
                }
                $call =~ tr/ACTGactg/TGACtgac/ if $strand eq '-';
            }
            $new_calls{$chr}{$phys} = $calls->{$snp_id};
            delete $calls->{$snp_id};
        }

    }
    return \%new_calls;
}



1;

sub help_brief {
    "Converts Affy genotype call file into actual base calls"
}
