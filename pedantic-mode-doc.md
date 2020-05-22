Pedantic Mode is a compilation option built into Stanc3 that warns you about potential issues in your Stan program.

For example, if you compile the following program with Pedantic Mode:

    data {
      int N;
      real x[N];
    }
    parameters {
      real sigma;
    }
    model {
      real mu;
      x ~ normal(mu, sigma);
    }

The compiler will print the following to stderr:

    Warning:
      The parameter sigma has no priors.
    Warning at '../pedantic-mode-prose/ped-mode-ex1.stan', line 10, column 14 to column 16:
      The variable mu may not have been assigned a value before its use.
    Warning at '../pedantic-mode-prose/ped-mode-ex1.stan', line 10, column 18 to column 23:
      A normal distribution is given parameter sigma as a scale parameter
      (argument 2), but sigma was not constrained to be strictly positive.

Here are the kinds of issues that Pedantic Mode will find:

-   Distribution arguments don't match the distribution specification. [Details](#org1022877).
-   Some specific distribution is used in an inadvisable way. [Details](#org76f6782).
-   Very large or very small constants are used as distribution arguments. [Details](#org80f3ed7).
-   Branching control flow (like if/else) depends on a parameter value. [Details](#org5d5eb29).
-   A parameter is defined but doesn't contribute to target. [Details](#org9d08cd0).
-   A parameter is on the left-hand side of multiple twiddles. [Details](#orgfde22de).
-   A parameter has more than one prior distribution. [Details](#orgc19ae8e).
-   A parameter is given questionable bounds. [Details](#org67085ac).
-   A variable is used before being assigned a value. [Details](#orgc242be3).

For a current list of pedantic mode's limitations; see [here](#orga38fd10).


## Warning documentation


### [Updated] Distribution warnings

1.  Argument and variate constraint warnings

    <a id="org1022877"></a>
     There is a warning for each constrained argument of each built-in distribution, based on the information from the Functions Reference. These include for example inclusive/exclusive upper and lower bounds, covariance matrices, cholesky correlation matrices, simplexes, etc.
    
    An exception is discrete distributions. I can't yet check the bounds of discrete variables or data variables. That'll be a future update.
    
    An argument constraint is checked for consistency against the parameter declaration or literal value (or what becomes a literal value after partial evaluation). For example, if a parameter is used as a scale parameter and is constrained to be lower=1, no warning is generated, but if it were constrained lower=-1, a warning is generated.
    
    Warning messages try to be as descriptive as possible, including English descriptions of the argument role (e.g. "a scale parameter") and the constraint (e.g. "constrained to be positive"), as well as the distribution name, variable name and location.
    
    Here's an example message pulled from a test in test/unit/Pedantic<sub>mode.ml</sub>:
    
        Warning at 'string', line 84, column 17 to column 22:
          A chi_square distribution has parameter unb_p as degrees of freedom
          (argument 1), but unb_p is not constrained to be positive.
    
    This language could probably be improved if anyone wants to reformat it.
    
    Speaking of tests, all of the warnings have at least one test in the above mentioned file. There will likely still be bugs if I misinterpreted the Function Reference.

2.  Special distribution warnings

    <a id="org76f6782"></a>
    
    1.  Uniform distribution
    
        Warn on any use when the variate parameter's bound constraint doesn't match the uniform bounds
    
    2.  (Inverse) Gamma distribution
    
        Warn when arguments indicate that it might be a poor attempt at an improper prior
    
    3.  lkj<sub>corr</sub> distribution
    
        Warn on use to suggest using Cholesky variant


### [Updated] Parameter defined but never used

<a id="org9d08cd0"></a>
I now build a factor graph and check that there are no declared parameters missing from the factor graph. This should effectively check if any factors don't contribute (even indirectly) to the target value.


### [Updated] Large or small numbers

<a id="org80f3ed7"></a>
Update: Only checking numbers which are used as arguments to built-in distributions.

1.  Description

    Andrew's suggested message:
     Warning message: "Try to make all your parameters scale free. You have a constant in your program that is less than 0.1 or more than 10 in absolute value on line ****. This suggests that you might have parameters in your model that have not been scaled to roughly order 1. We suggest rescaling using a multiplier; see section \***** of the manual for an example.

2.  Implementation notes

    Look though all expressions for large numbers. I'm guessing there will be a lot of false positives, I'm wondering how best to narrow it down to the real issue.
    
    I also allowed 0 without a warning.


### Control flow dependent on parameters

<a id="org5d5eb29"></a>

1.  Description

    Control flow statements in the log<sub>prob</sub> section should not depend in any way on the value of parameters, else they might introduce discontinuity.

2.  Implementation notes

    Heavy use of dependence analysis. Iterates through all control flow statements, finds all the dependencies of their branching decision expressions, and checks that those have no parameter dependencies


### Parameter on LHS of multiple twiddles

<a id="orgfde22de"></a>

1.  Implemenation notes

    Search program for twiddles (which only look like top-level TargetPE plus a distribution), look for duplicate LHS parameters
    
    Only catches multiple twiddles in the code, not execution, so does not e.g. catch twiddles within a loop.
    
    Does not handle array indexing at all, only string matches the parameters.


### Parameter with /=1 priors

<a id="orgc19ae8e"></a>

1.  Description

    Warn user if parameter has no priors or multiple priors Bruno Nicenboim suggested this on <https://github.com/stan-dev/stan/issues/2445>)

2.  Implementation notes

    The definition of 'prior' seems tricky in Stan. I came up with a definition that makes sense to me.
    
    A likelihood is P(X|D,Y), a prior is P(X|Y), where Y are non-data variables. So the important feature seems to be the lack of dependence on data. But not 'dependence' in the programming sense, dependence in the probabilistic sense.
    
    We can use a factor graph to translate the idea to Stan. If we're wondering whether a neighboring factor F of a variable V is a prior, we should check whether F has any connection to the data that isn't intermediated by V. To do that, we can remove V from the graph and look for any path between F and the data using BFS.
    
    The results using this definition seem to match my intuition, but I'm betting others will have some thoughts.


### Undefined variables

<a id="orgc242be3"></a>

1.  Implemenation notes

    I haven't worked on this for the PR, I just added it to the &#x2013;warn-pedantic flag and relocated the code.
    
    It still does not handle array elements, that's another big TODO.


### Parameter bounds

 <a id="org67085ac"></a>
 NOTE: also nonsense bounds
Parameter bounds of the form "lower=A, upper=B" should be flagged in all cases except A=0, B=1 and A=-1, B=1.

1.  Implementation notes

    I was a little fuzzy on when bounds will be Ints vs. Reals. I ended up casting everything to float, which might backfire.


## Limitations

<a id="orga38fd10"></a>


### Handle array elements in dependency analysis

Indexed variables are not handled intelligently, so they're treated conservatively (erring toward no warnings)


### Figure out how to persist data variable constraints into the MIR

When I can do this, I also catch more issues with discrete distributions
Data variables used as distribution arguments or variates are not currently checked against distribution specifications


### Control flow dependent on parameters in nested functions


### Sometimes it's impossible to know a variable's value, like a distribution argument, before the program is run


# Dummy

