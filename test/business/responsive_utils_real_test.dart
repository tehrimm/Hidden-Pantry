import 'package:flutter_test/flutter_test.dart';
import 'package:hidden_pantry_app/core/utils/responsive_utils.dart';

void main() {
  group('Real Business Tests: ResponsiveUtils', () {
    setUp(() {
      // Manually set dimensions for testing without a BuildContext
      ResponsiveUtils.screenWidth = 393.0;
      ResponsiveUtils.screenHeight = 852.0;
      ResponsiveUtils.wScale = 1.0;
      ResponsiveUtils.hScale = 1.0;
    });

    test('sw calculates width scale correctly', () {
      // With wScale = 1.0, sw(100) should be 100
      expect(ResponsiveUtils.sw(100), 100.0);

      // Simulate smaller screen width
      ResponsiveUtils.wScale = 300.0 / 393.0; // approx 0.763
      expect(ResponsiveUtils.sw(100), closeTo(76.3, 0.1));
    });

    test('sh calculates height scale correctly', () {
      // With hScale = 1.0, sh(100) should be 100
      expect(ResponsiveUtils.sh(100), 100.0);

      // Simulate larger screen height
      ResponsiveUtils.hScale = 1000.0 / 852.0; // approx 1.173
      expect(ResponsiveUtils.sh(100), closeTo(117.3, 0.1));
    });

    test('Device classification breakpoints', () {
      // Mobile (<600)
      ResponsiveUtils.screenWidth = 400;
      expect(ResponsiveUtils.isSmallScreen(), true);
      expect(ResponsiveUtils.isTablet(), false);
      expect(ResponsiveUtils.isLargeScreen(), false);

      // Tablet (600 - 1199)
      ResponsiveUtils.screenWidth = 800;
      expect(ResponsiveUtils.isSmallScreen(), false);
      expect(ResponsiveUtils.isTablet(), true);
      expect(ResponsiveUtils.isLargeScreen(), false);

      // Desktop (>= 1200)
      ResponsiveUtils.screenWidth = 1400;
      expect(ResponsiveUtils.isSmallScreen(), false);
      expect(ResponsiveUtils.isTablet(), false);
      expect(ResponsiveUtils.isLargeScreen(), true);
    });

    test('ResponsiveExtension applies methods correctly', () {
      // Requires the extension methods on num
      ResponsiveUtils.wScale = 2.0;
      ResponsiveUtils.hScale = 3.0;

      expect(10.sw, 20.0);
      expect(10.sh, 30.0);
    });
  });
}
