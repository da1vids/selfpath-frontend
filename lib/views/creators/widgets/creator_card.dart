import 'package:flutter/material.dart';
import '../../../../models/creator_model.dart';
import '../../../theme/theme.dart';

class CreatorCard extends StatelessWidget {
  final Creator creator;
  final VoidCallback onToggle;

  const CreatorCard({Key? key, required this.creator, required this.onToggle})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    AppTheme.accentColor, // Change to your desired border color
                width: 2, // Thickness of the border
              ),
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(
                creator.profilePicture ?? 'https://i.pravatar.cc/150?img=1',
              ),
              backgroundColor: Colors.transparent,
            ),
          ),

          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      creator.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '@${creator.username}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 4),
                Text(
                  creator.bio ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[400]),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${creator.followersCount} followers',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    creator.followed
                        ? ElevatedButton(
                          onPressed: onToggle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 15,
                            ),
                            minimumSize: Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity(
                              horizontal: -2,
                              vertical: -2,
                            ),
                            textStyle: TextStyle(fontSize: 12),
                          ),
                          child: Text('Following'),
                        )
                        : OutlinedButton(
                          onPressed: onToggle,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: AppTheme.accentColor),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 15,
                            ),
                            minimumSize: Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity(
                              horizontal: -2,
                              vertical: -2,
                            ),
                            textStyle: TextStyle(fontSize: 12),
                          ),
                          child: Text('Follow'),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
