#!/gsc/bin/perl

use IO::File;

my $fh = IO::File->new($ARGV[0]);
my $bam_file = $ARGV[1];
my $dir=$ARGV[2];
$count=0;
`rm -f $dir/temp/*.bam`;
while(my $line = $fh->getline) {
    chomp $line;
    my($sample,$chr,$start,$stop) = split /\t/, $line;
    my $cmd ="samtools view -b -h $bam_file $chr:$start-$stop > $dir/temp/$count.bam";
    `$cmd`;
    $count++;
}

`samtools merge output.bam $dir/temp/*.bam`;

