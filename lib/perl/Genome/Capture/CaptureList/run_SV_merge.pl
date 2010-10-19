
#use strict;
use Cwd;
use Config::IniFiles;
use File::Path qw(make_path);



my $ini_file = $ARGV[0];
if(!-e $ini_file || -z $ini_file) {
    print STDERR "Cannot find $ini_file.  Exiting\n";
    exit 5;
}

my $cfg = Config::IniFiles->new( -file => $ini_file);

my $current_dir = getcwd();
my $project = rem_white_space($cfg->val('REQUIRED','project'));
my $out_dir = rem_white_space($cfg->val('REQUIRED','output_dir'));
my ($proj,$num) = ($project =~ /([^\d]+)(\d+)/); 

my $output_dir = "${out_dir}/${project}/no_filters";

if(!-d "$output_dir") {
    make_path("$output_dir");
}

#default configuration file
my $config = "merge_config.txt";
my $config_ctx = "merge_config_ctx.txt";


make_config_file($ini_file,$project,$output_dir);
make_comparison();



sub make_comparison{

    my $exit_code=0;

    #run intrachromosomal comparison
    print STDERR "run intrachromosomal comparison\n";
    my $cmd = "perl bigComparison_final_simple_more.pl -h -n -r 0.75 ${output_dir}/${config} > ${output_dir}/$project";
    $exit_code = system($cmd);
    while($exit_code) {
	print STDERR "rerunnning $cmd\n";
	$exit_code = system($cmd);
    }

    #run interchromosomal comparison
    print STDERR "run interchromosomal comparison\n";
    my $sv_file = $cfg->val('BreakDancer','file'); #grab a random SV file
    $cmd = "perl bigComparison_final_simple_more.pl -h -n -x 1 ${output_dir}/${config_ctx} ${sv_file} > ${output_dir}/${project}_ctx";
    $exit_code = system($cmd);
    while($exit_code) {
	print STDERR "rerunnning $cmd\n";
	$exit_code = system($cmd);
    }

    #
    $cmd = "grep BD ${output_dir}/${project} | grep -v AS | perl -ane '\$a=0; foreach ( \@F[1..\$#F] ) { ( \$ncn,\$tcn ) = ( \$_=~/Ncn(\\S+)\:Tcn(\\S+)/ ) ; ( \$tp ) = (\$_=~/tp(\\S+):/); \$a = 1 if(\$ncn - \$tcn > 0.5 && \$tp =~ /DEL/ || \$tcn-\$ncn>0.5 && \$tp =~ /ITX/);} print \"\$_\" if(\$a);\' > ${output_dir}/${project}.CR2.tmp";
    system($cmd);
    while($exit_code) {
	print STDERR "rerunnning $cmd\n";
	$exit_code = system($cmd);
    }

    #filter step
    print STDERR "Run Filter\n";
    $cmd = "perl filters.pl ${output_dir}/${project}.CR2.tmp ${output_dir}/${project}.CR2 ${output_dir}/${project}.CR2.filteredout";
    system($cmd);
    while($exit_code) {
	print STDERR "rerunnning $cmd\n";
	$exit_code = system($cmd);
    }

    print STDERR "Run Count\n";
    $cmd = "./count_CRs.sh ${out_dir}/${project} $proj $num > $output_dir/${proj}.count1";
    system($cmd);
    while($exit_code) {
	print STDERR "rerunnning $cmd\n";
	$exit_code = system($cmd);
    }
    #gmt nimblegen design-from-sv --sv-file /gscuser/ndees/no_filters/LUC1.capture --output-file /gscuser/ndees/no_filters/LUC1.nimblegen --count-file /gscuser/ndees/no_filters/LUC.count2
  


}


sub inter_chromosomal_comparison {

    
    my $sv_file = $cfg->val('BreakDancer_FILE','chr1'); #grab a random SV file

    my $cmd = "perl bigComparison_final_simple_more.pl -h -n -x 1 ${output_dir}/${config_ctx} ${sv_file} > ${output_dir}/${project}_ctx";
    system($cmd);


}


sub make_config_file {

    my $ini_file = shift;
    my $project = shift;
    my $out_dir = shift;

    my $cfg = Config::IniFiles->new( -file => $ini_file );

    open(OUT, "> $output_dir/$config" ) or die "Unable to write to config.txt\n";
    
    my ($header,$loc,$line_skip,$rule);
      
    #assembly_file
    if($cfg->val('Assembly','all_file')){
    $header = "${project}.AS";
    $loc = rem_white_space($cfg->val('Assembly','all_file'));  
    $line_skip = 0;
    $rule = rem_white_space($cfg->val('Rules','AS'));
    print OUT "$header\t$loc\t$line_skip\t$rule\n";
}

    ($header,$loc,$line_skip,$rule)=();

    if($cfg->val('SquareDancer','file')){
    #squaredancer_file
    $header = "${project}.SD";
    $loc = rem_white_space($cfg->val('SquareDancer','file'));  
    $line_skip = 0;
    $rule = $cfg->val('Rules','SD');
    print OUT "$header\t$loc\t$line_skip\t$rule\n";
}
    
 
    ($header,$loc,$line_skip,$rule)=();
   #breakdancer_files
   if($cfg->val('BreakDancer','dir')){
    my @chrom = (1 .. 22);
    my @chrom = (@chrom, 'X', 'Y');

    my $header_base = "${project}.BD";
    foreach my $x (@chrom) {
	my $suffix = "chr${x}";
	$header = "$header_base.${suffix}"; 
	my $loc_dir = rem_white_space($cfg->val('BreakDancer','dir'));
	$loc = "$loc_dir/${project}/${project}.${suffix}.sv";
	$line_skip = 0;
	$rule = $cfg->val('Rules','BD');
	print OUT "$header\t$loc\t$line_skip\t$rule\n";
    }
}
    ($header,$loc,$line_skip,$rule)=();
    #Copy-number_file
    if($cfg->val('CNA','file')){
    $header = "${project}.CNA";
    $loc = $cfg->val('CNA','file');  
    $line_skip = 0;
    $rule = rem_white_space($cfg->val('Rules','CN'));
    print OUT "$header\t$loc\t$line_skip\t$rule\n";
}
    close OUT;

    open(OUT, "> $output_dir/$config_ctx" ) or die "Unable to write to config_ctx.txt\n";
    ($header,$loc,$line_skip,$rule)=(); 
    #assembly_ctx_file
    if($cfg->val('Assembly','CTX_file')){
    $header = "${project}.AS";
    $loc = rem_white_space($cfg->val('Assembly','CTX_file'));  
    $line_skip = 0;
    $rule = rem_white_space($cfg->val('Rules','CTX'));
    print OUT "$header\t$loc\t$line_skip\t$rule\n";
}

    if($cfg->val('SquareDancer','file')){
    $header = "${project}.SD";
    $loc = rem_white_space($cfg->val('SquareDancer','file'));  
    $line_skip = 0;
    $rule = rem_white_space($cfg->val('Rules','SD'));
    print OUT "$header\t$loc\t$line_skip\t$rule\n";
}

    close OUT;

}


sub rem_white_space {

    my $string = shift;

    $string =~ s/^\s+//g;
    $string =~ s/\s+$//g;

    return $string;

}
