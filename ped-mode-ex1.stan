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
