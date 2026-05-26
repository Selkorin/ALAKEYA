import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('knowledge_files')
export class KnowledgeFile {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  projectId: string;

  @Column()
  socialAccountId: string;

  @Column()
  fileName: string;

  @Column()
  fileType: 'pdf' | 'docx' | 'txt' | 'image' | 'audio' | 'link';

  @Column()
  fileUrl: string;

  @Column('text', { nullable: true })
  parsedText: string;

  @Column({ nullable: true })
  embeddingId: string;

  @CreateDateColumn()
  createdAt: Date;
}
