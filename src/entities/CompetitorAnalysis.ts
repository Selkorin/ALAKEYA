import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('competitor_analysis')
export class CompetitorAnalysis {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  projectId: string;

  @Column()
  socialAccountId: string;

  @Column()
  platform: 'instagram' | 'telegram' | 'vk' | 'youtube' | 'tiktok';

  @Column()
  competitorHandle: string;

  @Column({ nullable: true })
  competitorUrl: string;

  @Column('json')
  metrics: {
    totalPosts: number;
    totalFollowers: number;
    avgLikes: number;
    avgComments: number;
    avgShares: number;
    engagementRate: number;
  };

  @Column('json')
  contentAnalysis: {
    topContentTypes: string[];
    topHashtags: string[];
    bestPostingTimes: string[];
    postFrequency: string;
    captions: {
      avgLength: number;
      patterns: string[];
    };
    visualStyle: {
      colorPalette: string[];
      filterUsage: string[];
      description: string;
    };
  };

  @Column('json')
  topPosts: Array<{
    title: string;
    likes: number;
    comments: number;
    shares: number;
    engagement: number;
    contentType: string;
    postedAt: string;
  }>;

  @Column('text')
  aiReport: string;

  @Column('json')
  recommendations: Array<{
    title: string;
    description: string;
    action: string;
    priority: 'high' | 'medium' | 'low';
  }>;

  @Column()
  status: 'pending' | 'analyzing' | 'completed' | 'failed';

  @Column({ nullable: true })
  errorMessage: string;

  @CreateDateColumn()
  createdAt: Date;

  @Column({ nullable: true })
  completedAt: Date;
}
