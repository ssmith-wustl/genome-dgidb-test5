package Genome::Model::Tools::Bmr::SmgTest;

use strict;
use warnings;
use IO::File;
use Genome;
use Cwd;

class Genome::Model::Tools::Bmr::SmgTest {
    is => 'Command',
    has => [
    gene_summary => {
        is => 'String',
        is_optional => 0,
        doc => 'File containing per-gene BMR info from \'gmt bmr gene-summary\'.',
    },
    class_summary => {
        is => 'String',
        is_optional => 0,
        doc => 'File containing per-class BMR info from \'gmt bmr class-summary\'.',
    },
    ]
};

sub help_brief {
    "Run the SMG test in R."
}

sub help_detail {
    "Takes as input output from gmt bmr gene-summary, and run's Qunyuan's SMG test which is coded in R."
}

sub execute {
    my $self = shift;
    $DB::single=1;
    my $rlibrary = "SMG_test.R";

    #Parse input
    my $genefile = $self->gene_summary;
    unless (-s $genefile) {
        $self->status_message("BMR file not found.");
        return;
    }
    my $test_output = $genefile . ".smgtest";
    my $outfile = $test_output . ".final_results";
    my $fdrfile = $test_output . ".fdr";

    #Call R for smg test
    my $smg_test_cmd = "smg_test(in.file='$genefile',test.file='$test_output',fdr.file='$fdrfile');";
    my $smg_test_rcall = Genome::Model::Tools::R::CallR->create(command=>$smg_test_cmd,library=>$rlibrary);
    $smg_test_rcall->execute;

    #Print final output file
    my $outfh = new IO::File $outfile,"w";
    
    #grab classes from the bmr file
    my @classes;
    my $classesref = \@classes;
    my $class_file = $self->class_summary;
    my $classfh = new IO::File $class_file,"r";
    while (my $line = $classfh->getline) {
        print $outfh $line;
        next if $line =~ /class/i;
        my ($class) = split /\t/,$line;
        push @classes,$class;
    }
    $classfh->close;
    @classes = sort @classes;
    

    #Gather FDR stats
    my $fdrfh = new IO::File $fdrfile,"r";
    my %FDR;
    my $fdr = \%FDR;
    while (my $line = $fdrfh->getline) {
        next if $line =~ /gene/i;
        chomp $line;
        my ($gene,$pfisher,$plr,$pconvol,$fdrfisher,$fdrlr,$fdrconvol) = split /\t/,$line;
        $FDR{$gene}{'pfisher'} = $pfisher;
        $FDR{$gene}{'plr'} = $plr;
        $FDR{$gene}{'pconvol'} = $pconvol;
        $FDR{$gene}{'fdrfisher'} = $fdrfisher;
        $FDR{$gene}{'fdrlr'} = $fdrlr;
        $FDR{$gene}{'fdrconvol'} = $fdrconvol;
    }
    $fdrfh->close;

    #Print outfile header
    print $outfh "Gene\tTotal_Muts\t";
    print $outfh "$classes[0]_muts\t$classes[1]_muts\t$classes[2]_muts\t$classes[3]_muts\t$classes[4]_muts\t$classes[5]_muts\t$classes[6]_muts\t";
    print $outfh "$classes[0]_cov\t$classes[1]_cov\t$classes[2]_cov\t$classes[3]_cov\t$classes[4]_cov\t$classes[5]_cov\t$classes[6]_cov\t";
    print $outfh "p.fisher\tp.lr\tp.convol\tfdr.fisher\tfdr.lr\tfdr.convol\n";

    #Loop through BMR file and gather and print mutation information.
    my %COVMUTS;
    my $covmuts = \%COVMUTS;
    
    my $genefh = new IO::File $genefile,"r";
    while (my $line = $genefh->getline) {
        next if $line =~ /class/i;
        my ($nextgene,$class,$cov,$muts) = split /\t/,$line;
        unless (defined $COVMUTS{'gene'}) {
            $COVMUTS{'gene'} = $nextgene;
        }
        if ($nextgene eq $COVMUTS{'gene'}) {
            $COVMUTS{$class}{'cov'} = $cov;
            $COVMUTS{$class}{'muts'} = $muts;
        }
        if ($nextgene ne $COVMUTS{'gene'}) {
            
            #we are at next gene in file, so print output from the last gene
            my $gene2print = $COVMUTS{'gene'};
            
            $self->print_gene($gene2print,$classesref,$covmuts,$fdr,$outfh);
            
            $COVMUTS{'gene'} = $nextgene;
            $COVMUTS{$class}{'cov'} = $cov;
            $COVMUTS{$class}{'muts'} = $muts;
        }
    }

    $self->print_gene($COVMUTS{'gene'},$classesref,$covmuts,$fdr,$outfh);
    
    return 1;
}

sub print_gene {
    
    my ($self,$gene2print,$classesref,$covmuts,$fdr,$outfh) = @_;

    my $total_muts;

    for my $class (@$classesref) {
        next if $class =~ m/gene/i;
        $total_muts += $covmuts->{$class}->{'muts'};
    }
    
    #print mutation info
    print $outfh "$covmuts->{'gene'}\t$total_muts\t";
    for my $class (@$classesref) {
        print $outfh "$covmuts->{$class}->{'muts'}\t";
    }

    #print coverage info
    for my $class (@$classesref) {
        print $outfh "$covmuts->{$class}->{'cov'}\t";
    }

    #print pvalue and fdr info. If undefined, then it had no coverage
    if( defined $fdr->{$gene2print}->{'pfisher'} )
    {
        print $outfh "$fdr->{$gene2print}->{'pfisher'}\t$fdr->{$gene2print}->{'plr'}\t$fdr->{$gene2print}->{'pconvol'}\t";
        print $outfh "$fdr->{$gene2print}->{'fdrfisher'}\t$fdr->{$gene2print}->{'fdrlr'}\t$fdr->{$gene2print}->{'fdrconvol'}\n";
    }
    else
    {
        print $outfh "NC\tNC\tNC\tNC\tNC\tNC\n";
    }
}

1;
