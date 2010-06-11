#!/gsc/bin/perl
use IO::File;
#my $file = $ARGV[0];
#my $bam = $ARGV[1];
my $dir = $ARGV[0];
my @sites_files = glob("$ARGV[0]/*.csv");
my @bam_files = glob ("$ARGV[0]/*.bam");



for my $file (@sites_files) {
    my ($name) = ($file =~ m/(SJC[MR][^_]*_)/);
    my ($count, $found);

    for my $bam (grep /$name/, @bam_files) {
        $count=0; $found=0;   

        my $fh = IO::File->new($file);
        while (my $line = $fh->getline) {
            chomp $line;
            my ($chr, $pos, ) = split /\t/, $line;
            my $output = `samtools view -b $bam | samtools pileup - | grep "^$chr	$pos"`;
            if($output) {
                $found++;
            }
            else {
                print "$chr, $pos, $pos not found\n";
            }
            $count++;
        }
         
        $fh->close;
        print "$file\t$bam\tLines in ROI list:$count\tSites with Data:$found\n";
    }
}
