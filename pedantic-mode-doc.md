
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
    Warning at 'ped-mode-ex1.stan', line 10, column 14 to column 16:
      The variable mu may not have been assigned a value before its use.
    Warning at 'ped-mode-ex1.stan', line 10, column 18 to column 23:
      A normal distribution is given parameter sigma as a scale parameter
      (argument 2), but sigma was not constrained to be strictly positive.

Here are the kinds of issues that Pedantic Mode will find:

-   Distribution arguments don't match the distribution specification. [Details here](#orgc4e1d29).
-   Some specific distribution is used in an inadvisable way. [Details here](#org666feb5).
-   Very large or very small constants are used as distribution arguments. [Details here](#org975b60e).
-   Branching control flow (like if/else) depends on a parameter value. [Details here](#org9f17caa).
-   A parameter is defined but doesn't contribute to target. [Details here](#orge315e55).
-   A parameter is on the left-hand side of multiple twiddles. [Details here](#org4ce0054).
-   A parameter has more than one prior distribution. [Details here](#org2a77905).
-   A parameter is given questionable bounds. [Details here](#orgad71dac).
-   A variable is used before being assigned a value. [Details here](#orga70a9f6).

For a current list of pedantic mode's limitations, see [here](#orgb5df36f).


## Warning documentation


### Distribution warnings


#### Argument and variate constraint warnings

<a id="orgc4e1d29"></a>
When an argument to a built-in distribution certainly does not match that distribution's specification in the [Stan Functions Reference](https://mc-stan.org/docs/functions-reference/index.html), a warning is thrown. This primarily checks if any distribution argument's bounds at declaration, compile-time value, or subtype at declaration (e.g. `simplex`) is incompatible with the domain of the distribution.

For example, in the following program:

    parameters {
      real unb_p;
      real<lower=0> pos_p;
    }
    model {
      1 ~ poisson(unb_p);
      1 ~ poisson(pos_p);
    }

The parameter of `poisson` should be strictly positive, but `unb_p` is not constrained to be positive.
This produces the following warning:

    Warning at 'dist-warn-ex1.stan', line 6, column 14 to column 19:
      A poisson distribution is given parameter unb_p as a rate parameter
      (argument 1), but unb_p was not constrained to be strictly positive.


#### Special-case distribution warnings

<a id="org666feb5"></a>
Pedantic mode checks for some specific uses of distributions that may indicate a statistical mistake:


##### Uniform distributions

Any use of uniform distribution generates a warning, except when the variate parameter's declared `upper` and `lower` bounds exactly match the uniform distribution bounds.
In general, assigning a parameter a uniform distribution can create non-differentiable boundary conditions and is not recommended.


##### (Inverse-) Gamma distributions

Gamma distributions are sometimes used as an attempt to assign an improper prior to a parameter.
Pedantic mode gives a warning when the Gamma arguments indicate that this may be the case.


##### lkj\_corr distribution

Any use of the `lkj_corr` distribution generates a warning that suggests using the Cholesky variant instead.
See <https://mc-stan.org/docs/functions-reference/lkj-correlation.html> for details.


### Parameter is never used

<a id="orge315e55"></a>
A warning is generated when a parameter is declared but does not have any effect on the program.
This is determined by checking whether the value of the `target` variable depends in any way on each of the parameters.


### Large or small constants in a distribution

<a id="org975b60e"></a>
When numbers with magnitude less than 0.1 or greater than 10 are used as arguments to a distribution, it indicates that some parameter is not scaled to unit value, so a warning is thrown.
See <https://mc-stan.org/docs/stan-users-guide/standardizing-predictors-and-outputs.html> for a discussion of scaling parameters.


### Control flow depends on a parameter

<a id="org9f17caa"></a>
Control flow statements, such as `if`, `for` and `while`, should not depend on the value of the parameters to determine their branching conditions.
Otherwise, the program may branch differently between iterations, which is likely to introduce discontinuity into the density function.
Pedantic mode generates a warning when any branching condition may depend on a parameter value.


### Parameter has multiple twiddles

<a id="org4ce0054"></a>
A warning is generated when a parameter is found on the left-hand side of more than one `~` statements (or an equivalent `target +=` conditional density statement).
This pattern is not inherently an issue, but it is unusual and may indicate a mistake.

Pedantic mode only searches for repeated statements, it will not for example generate a warning when a `~`statement is executed repeatedly inside of a loop.


### Parameter has zero or multiple priors

<a id="org2a77905"></a>
A warning is generated when a parameter appears to have greater than or less than one prior distribution factor.

This analysis depends on a [*factor graph*](https://en.wikipedia.org/wiki/Factor_graph) representation of a Stan program. A factor F that depends on a parameter P is called a *prior factor for P* if there is no path in the factor graph from F to any data variable except through P.


### Variable is used before assignment

<a id="orga70a9f6"></a>
A warning is generated when any variable is used before it has been assigned a value.
This warning is also available as a standalone option to Stanc3, with the flag: `--warn-uninitialized`.


### Strict or nonsensical parameter bounds

<a id="orgad71dac"></a>
Parameters that are have strict `upper` and `lower` bounds can cause unmanageably large gradients in a density function, and may only be justified in a few cased.
A warning is generated for all parameters declared with the bounds `<lower=.., upper=..>` except for `<lower=0, upper=1>` or `<lower=-1, upper=1>`.

In addition, a warning is generated when a parameter bound is found to have `upper - lower <= 0`.


## Limitations

<a id="orgb5df36f"></a>


#### Constant values are sometimes uncomputable

Pedantic mode attempts to evaluate expressions down to literal values so that they can be used to generate warnings.
For example, in the code `normal(x, 1 - 2)`, the expression `1 - 2` will be evaluated to `-1`, which is not a valid variance argument so a warning is generated.
However, this strategy is limited; it is often impossible to fully evaluate expressions in finite time.


#### Container types

Currently, indexed variables are not handled intelligently, so they are treated as monolithic variables.
Each analysis treats indexed variables conservatively (erring toward generating fewer warnings).


#### Data variables

The declaration information for `data` variables is currently not considered, so using `data` as incompatible arguments to distributions may not generate the appropriate warnings.


#### Control flow dependent on parameters in nested functions

If a parameter is passed as an argument to a user-defined function within another user-defined function, and then some control flow depends on that argument, the appropriate warning will not be thrown.


# Dummy

