# This file is maintained automatically by "tofu init".
# Manual edits may be lost in future updates.

provider "registry.opentofu.org/fluxcd/flux" {
  version     = "1.8.7"
  constraints = ">= 1.8.6"
  hashes = [
    "h1:9m+Ue+7cdW9bwwOUL5lq0v/I6F+rqIeyGO2S5y3X0+w=",
    "h1:GDolu6I9VEZl/f5Cj+tn6xR155Zb3ok9wT2ozs1UPJ0=",
    "h1:JIW+oatg31Qxdbg6Zcee8qPBtKnscNNbHLnj1ex2geA=",
    "h1:JxpRe/47g9HMlD2cGMnNUQ8NHKCfIVEuZ5RGjBM2gt8=",
    "h1:L03QZoyYgGvXqIcPCRMD/8SIneByA2JNXWFpr1Cf82o=",
    "h1:RwKmxpFxfuP2qlq+enJCygvuMhmMF3RlVhskW5IgBlU=",
    "h1:SZvLauxCBX6Uh/l1KuFpALtn6aGtCmh+llG9/Jy9O7E=",
    "h1:U33xENjrsgDB59jL/D/OqRlc63gs3NFziNEDRmt55vw=",
    "h1:hRfxmbtaxYRjFw0lbFY2E+yPwGMV9FOyp1nW0ss9LRs=",
    "h1:k3tyzMq748cwfKxYm1qDwTehmPuIwn5GRl3EfSAGf6Y=",
    "h1:mz5C7cZEIkUTgsjGFY7ueTzXscoOzzn4TDxKqMPhdrY=",
    "zh:21b0f7b77d31d0608e9112d012159b2cf2b1f73b07b419a768ae4f961fc04293",
    "zh:3f3ca093a9e14244c043df1c061729c6861fc21bd43f0693904b814eeabaa7da",
    "zh:5e373ac4d63d95edbafa4ecd826018bd1f8c6f4fd54b58fe35ea5cba50514ecb",
    "zh:8fe30c02daaa6ba1d03fdfec8632996dbe15a355e9c0a0db46761f3772ba8bdf",
    "zh:9d605d88571418c11584db0d7d4be336d8a819ebca2012191e8c70fd0adeeab9",
    "zh:ac94fc620d4ec064554a8cecfb9436bca62fce17afccc5b75a182358b5c20940",
    "zh:b267b6d95169e9989c800002da704d212fac7493ec1e4e1757721dbeb61a53c0",
    "zh:ca870feddcb1516358624aac74eadc48a486fb450d6d5d8cff7dc1acc30e0c28",
    "zh:d95dea2f808127397909b5ce55f991aabba37d7273468c0d2cfd8c6047d5f95b",
    "zh:e4c6e4fb8c517ecaf940e2dc3f1ecab9135718e9b0293da5408c0f2cedef73e1",
    "zh:f2e6b6c61d35006c346e50d6c5672ce742ac73c27302ebe58bcd2ad711a38efb",
  ]
}

provider "registry.opentofu.org/hashicorp/kubernetes" {
  version     = "3.1.0"
  constraints = ">= 2.37.0"
  hashes = [
    "h1:/D/wtR7M2/M8XyFisCgunY6xuO08qZyY5l9JJUrE9G4=",
    "h1:0M9Nu8YersHl84pfFTRiW5UfmoxQC3xKJ+Zkt5WjEv8=",
    "h1:4R9y0ysMZovTnl4szxToceJ5JS1uu7OOgekjwuovQ6k=",
    "h1:DyKnb8Iyd3s+aZGk1xZtz11e/NZ0wHepF5wlliyD42E=",
    "h1:G/xDJLXRCSnsGV68TBmziSUUDBSMkq8STHX+6A5zj2U=",
    "h1:H3HBAfrFZXjnphHsxX5CMdA/F+It0mZOcvNpRktyFl4=",
    "h1:N0CDf4vyABZZVeqm0ugeOn8QleQDuOiFjsPjrhxbZvA=",
    "h1:RAnhix31hZNl70BPnRUg1FL5pn+MO7vXVMw3bSBcWk4=",
    "h1:S0NfuadaHnXovFhjDBJJxyNKwJiv5Akp7qim51UEPEE=",
    "h1:feDLnMsw5S8mROkE9q+pRiuMqXwklHYr+YBvbKiUZF4=",
    "h1:jvaX3zytN4Yjj4bj87mEyNDSlwP6kyZOFW9Yx3w3fk4=",
    "h1:oRv5IPg0yU6CG1UdLXzfd6P3/SMxfe7+6R8CpZso9f0=",
    "h1:uzK7fv/bO4Pd6E2wu9NX29I52aPuYOtmWOYafBoRT4U=",
    "h1:xncv/7mJnTS43BojW0zDzCbawJDKnQhe8zVLR6NZ3CQ=",
    "h1:zZ6pD4oz5Yrcloaceq7/KGSH6fFbwyzC++PEMucx3XM=",
    "zh:06f1310b47ff31593766b4b664a508276e57f911c9e0237c6cb197a590e2d799",
    "zh:54aad7284e03c49996477f777c20b75ad12acbd68e80e86ecd1bd1ae6cfa5bea",
    "zh:5ad86522ff9343ac8a2b8b595ba7280de82966dd6feb6aa87b6b9103b694bf82",
    "zh:6506c8356b82f8c03f937efc68eee7a4ded1c77791552b530d3edf245ea97df4",
    "zh:6dab1c6eb3cb5c1738e1ca8c2c54e3ca30ef3a83dd3453491edbe2ff525e1392",
    "zh:754a9aef6d8456bae74bc2ab5a62c4c2146f0d79c4a817abe9d93567d1df26ef",
    "zh:75689548a4731f2f9f9ebe5fef971f3ee1464f1a0c4505f86ee1ef07cc228a0e",
    "zh:7e25f27dcbf73c5c83e9ee38a6e8110a8f889c902fc907e01a0820148d12604a",
    "zh:a080838edc0ebec1b556432fb1fde310effaa5ba5f504d105abbe6762e2acf07",
    "zh:a448d00988e100e201453b98d0098959c9b8e5dd34fbb33fe45793de0ae3d90e",
    "zh:d4b4da8b49e86d8dec76a147e9f9f1b541fa59607236c4e62105205edff5fc14",
    "zh:e712b9f90d9e29fa67990ef67cb9391db408414fb4c2261bc7522ecfba740fc0",
    "zh:e8c6b874b9e8f03411f1fb38d6273bec8037a007b32d11fd75b18f8befcbde03",
    "zh:f505fa05dee07f3d904208b9b9b8b13fd386093ae8243f2d7ce131f279310268",
    "zh:fc3c74b661a1c86b3dd78b0f3bd9256123f6b270c3627975a6f9dc231bf7a59c",
  ]
}

provider "registry.opentofu.org/oracle/oci" {
  version     = "8.14.0"
  constraints = ">= 8.3.0"
  hashes = [
    "h1:+ohMpBFaBb5HNIME99BZH/2tZ47CTTQdIE47kf3Qce0=",
    "h1:3OgSkxh4ttqNitGDBBFyVBc7mYTrV4vuPyZ0pUIjZdQ=",
    "h1:8uR8G+dh1QqkaFq+iL9TEd+fKeDX08vnubKPQw5bd2A=",
    "h1:AmJZqrFzLoVlPGZGH5IOg2eowmFfwHQ3T4Tq1TuJf1A=",
    "h1:E9Awn8FmkZ/eMxk2pMXtXx6gmuy9Q60hqYlg6aG/Ft8=",
    "h1:GD9SyetIxuyeGXSuP6NPu3xSAtxyk0LGNg2x1IocpvY=",
    "h1:KCkHjWAQlNHJOOBUj5+ZLcjARinGyPtazWnOhQi8aQ8=",
    "h1:QRt7KjYyaJ/wbP6qsv59zF2jJ1QjThKWZVU2yfN34oI=",
    "h1:d+H5YaSof6BWZ1ETLW3salOo17B2QBUWObUGsvV7B5s=",
    "h1:oV6v50a6OjILznvlMvcVMAHDGyf9iGupXM+YvKKcVsI=",
    "h1:sQozLGXZE1jUE8qn+tf6Ve9uKMtD1Z4Xlz05ZLNnMvs=",
    "h1:smRjcCCFS7AfXx3yVwy4oIZTwQNT1JnOc/P4ybijT3Y=",
    "h1:uGPagCV8aRiw+C2zQ5jUQy2D4bBOqSoz/4+aS6qf2+0=",
    "h1:zaYecJQSJdd+EQWm0cHE7rP+dgDnRW2CFtCiE6zo1tQ=",
    "zh:0f677f7609c10733f5a83d4add15a062b4b213fdcca53869611fc97bbae8e153",
    "zh:277d3376d94dc2dee083f4604d2d27a55beb79c5c81c31008926c255655f1351",
    "zh:30606342d76407d4199d612aa7ecf97e3e2630441dcbe91d54dc5efbf97a53ac",
    "zh:3d36211d264636167d3b2ae87226b003b9da3e8d5e31826ffd3d484d27a82061",
    "zh:5bdece1719420258b9eb7150db130d0c7cf1b26eb99bc19b781a7613d43d5a76",
    "zh:916f51472593ac4e0fac7fba292ab4a001cdb4991f50514c880b00e3f8699da2",
    "zh:99de6ad9bfddc28db2dbfc4022826eead1e287ba7f53e3da55419df7e6a5e46c",
    "zh:9b12af85486a96aedd8d7984b0ff811a4b42e3d88dad1a3fb4c0b580d04fa425",
    "zh:a03be6c6a73f0140022bc2ba0afc7377f55a2da48b1cac8b85b5c0a711d1df94",
    "zh:a1518b65e51f6b56807cfb570ff591a594f5a8f1168951a3a34183b3adc52a25",
    "zh:bb4ff42d8b8ebda39856a0776b158517e3da564ce17e0ba2d3e7818cdab8f838",
    "zh:bd5f07135742acd3d8e8b06476a0a2bde621a8707ed5f6f9499ac7cfa5ca73b1",
    "zh:bfe90d987619bbf42f359f88b46a66e16aeedf33130044cbcf8e6f0791c10ece",
    "zh:c8d969593b9ca8a3382896f3fd675af428b1647de3e78460dbfed793a02c4172",
    "zh:e2562ac49ab980da419822fd2a61be6957e3253b39600ebfd36d922e4788508d",
  ]
}
