package GSCApp::Print;
#-- this is not a sophisticated module.
#   But since things rely on GSCApp::Print::Barcode for things, we might as well have a GSCApp::Print
#   that has reciprocal functions
use strict;

our @all_printers;
our $d_printer;

sub printers{
    my $class = shift;
    #--- this is for linux and solaris only.  It's not capable of working on windows right now
    return @all_printers if @all_printers;
       
    my @lps = `lpstat -v`;
    chomp(@lps);

    my $def = $class->default_printer();
    foreach my $lp(@lps){
	my $loc;
        # parse out printer name
        if ($^O eq 'solaris') {
            ($loc) = $lp =~ m,/dev/(\w+),;
        }
        else{ # cups
            ($loc) = $lp =~ m,socket://(\w+):,;
        }
	if($lp =~ /\b$def\b/){
	    $def = $loc;
	}
	else{
	    push @all_printers, $loc;
	}
    }
    unshift @all_printers, $def;
    return @all_printers;
}


sub default_printer{
    my $class = shift;
    return $d_printer if $d_printer;

    my @d = `lpstat -d`;
    my ($def) = $d[0] =~ /\: (\w+)/;
    if($def eq 'lp'){
	@d = `lpstat -v lp`;
        if ($^O eq 'solaris') {
            ($def) = $d[0] =~ m,/dev/(\w+),;
        }
        else{ # cups
            ($def) = $d[0] =~ m,socket://(\w+):,;
        }
    }
    $d_printer = $def;
    return $d_printer;
}


1;
