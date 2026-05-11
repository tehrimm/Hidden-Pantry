import 'package:flutter/material.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';
import 'package:hidden_pantry_app/core/widgets/skeletons.dart';

class RecipeSkeletonLoader extends StatelessWidget {
  const RecipeSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18.sw, 18.sh, 18.sw, 90.sh),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

        children: [
           Center(child: Text("Loading Recipe...", style: TextStyle(color: Colors.grey, fontSize: 12.sp))),
           SizedBox(height: 10.sh),

           Row(children: [
             SkeletonBox(width: 50.sw, height: 50.sw, borderRadius: BorderRadius.all(Radius.circular(15.sw)), glassy: true),
             const Spacer(),
             SkeletonBox(width: 50.sw, height: 50.sw, borderRadius: BorderRadius.all(Radius.circular(15.sw)), glassy: true),
             SizedBox(width: 10.sw),
             SkeletonBox(width: 50.sw, height: 50.sw, borderRadius: BorderRadius.all(Radius.circular(15.sw)), glassy: true),
           ]),
           SizedBox(height: 18.sh),
           
           Row(children: [
             SkeletonBox(width: 42.sw, height: 42.sw, borderRadius: BorderRadius.all(Radius.circular(50.sw)), glassy: true),
             SizedBox(width: 12.sw),
             Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
               SkeletonBox(width: 100.sw, height: 14.sh, glassy: true),
               SizedBox(height: 6.sh),
               SkeletonBox(width: 60.sw, height: 10.sh, glassy: true),
             ]),
             const Spacer(),
             SkeletonBox(width: 60.sw, height: 34.sh, borderRadius: BorderRadius.all(Radius.circular(10.sw)), glassy: true),
           ]),
           SizedBox(height: 14.sh),
           
           SkeletonBox(width: double.infinity, height: 210.sh, glassy: true),
           SizedBox(height: 14.sh),
           
           SkeletonBox(width: 200.sw, height: 28.sh, glassy: true),
           SizedBox(height: 12.sh),
           
           Row(children: [
             Expanded(child: SkeletonBox(width: double.infinity, height: 60.sh, glassy: true)),
             SizedBox(width: 10.sw),
             Expanded(child: SkeletonBox(width: double.infinity, height: 60.sh, glassy: true)),
             SizedBox(width: 10.sw),
             Expanded(child: SkeletonBox(width: double.infinity, height: 60.sh, glassy: true)),
           ]),
           SizedBox(height: 20.sh),
           
           SkeletonBox(width: 150.sw, height: 24.sh, glassy: true),
           SizedBox(height: 10.sh),
           Column(
             children: List.generate(4, (i) => Padding(
               padding: EdgeInsets.only(bottom: 10.sh),
               child: Row(children: [
                 Expanded(child: SkeletonBox(width: double.infinity, height: 16.sh, glassy: true)),
                 SizedBox(width: 20.sw),
                 SkeletonBox(width: 40.sw, height: 16.sh, glassy: true),
               ]),
             )),
           )
        ],
      ),
    ),
  );
}

}

class RecipeErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const RecipeErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.sw),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 44.sw, color: Colors.redAccent),
            SizedBox(height: 12.sh),
            Text(
              "Error: $message",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF462F4D),
                fontSize: 13.sp,
                fontFamily: "Satoshi",
              ),
            ),
            SizedBox(height: 10.sh),
            TextButton(
              onPressed: onRetry,
              child: Text("Retry", style: TextStyle(fontSize: 14.sp, fontFamily: "Satoshi", fontWeight: FontWeight.bold, color: const Color(0xFFEF8A54))),
            ),
          ],
        ),
      ),
    );
  }
}
