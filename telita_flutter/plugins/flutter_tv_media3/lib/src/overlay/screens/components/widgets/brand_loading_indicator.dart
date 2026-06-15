import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class BrandLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const BrandLoadingIndicator({
    super.key,
    this.size = 60.0,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child:
          color != null
              ? ColorFiltered(
                colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
                child: Lottie.asset(
                  'assets/loading.json',
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  options: LottieOptions(enableMergePaths: true),
                ),
              )
              : Lottie.asset(
                'assets/loading.json',
                width: size,
                height: size,
                fit: BoxFit.contain,
                options: LottieOptions(enableMergePaths: true),
              ),
    );
  }
}
