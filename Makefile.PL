use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'	=> 'IRC::Bot',
    'VERSION_FROM' => 'Bot.pm', 
    'PREREQ_PM' => { 
                      POE::Component::IRC::Object => 0.02, 
                      Cache::Cache => 1.02
                   },
    'AUTHOR' => 'Benjamin W. Smith <defyance@perlmonk.org>',
);
